# -*- coding: utf-8 -*-
"""Bake a pattern onto the pig's UV sheet from the REAL mesh, in Blender.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
        --background --python bake_pattern.py

WHY THIS EXISTS, AND WHY IT REPLACES THE PYTHON SIDE OF `make_animal_maps.py`
FOR ANYTHING THAT DEPENDS ON WHERE A TEXEL IS IN SPACE.

`make_animal_maps.py` writes a PNG by walking (u, v) and computing an alpha.
That is exactly right for a pattern DEFINED in sheet coordinates -- spots on a
lattice, stripes at constant u, hoops at constant v -- and it is the wrong tool
the moment a pattern is defined in the WORLD, because then the generator has
to invert the unwrap: given a texel, where is that point on the animal?

It cost two bugs in one afternoon, both the same shape and neither visible in
any number this file prints:

  1. THE RADIUS MODEL. The inversion needs the pig's horizontal radius at a
     height, first written as sin(pi * body_t(v)) -- exact for a circle when t
     is the ANGULAR parameter, and body_t is linear in HEIGHT. Fifty-five per
     cent low at t = 0.10. The bee's bands bowed inward and read as swirls.

  2. THE SAMPLED PROFILE THAT REPLACED IT. Measured off the mesh in 21 bands
     of +-0.055 in z -- and near the crown the radius falls faster than the
     window is wide, so a band reports the radius at its BOTTOM edge. At
     z 0.851 it says 0.612 against a true 0.500. Bands that should cross the
     spine as straight lines closed into a rosette instead: reported as the
     stripes meeting at a vertex on the back.

BOTH ARE THE SAME MISTAKE THIS PROJECT ALREADY HAS A RULE ABOUT -- A
MEASUREMENT AGAINST A MODEL OF A THING IS NOT A MEASUREMENT OF THE THING --
and the inversion is unfixable in the general case anyway, because it assumes
a surface of revolution and the trim is not one. The snout straddles the axis,
which is what smeared the zebra's stripes across the muzzle.

BAKING DOES NOT INVERT ANYTHING. The correspondence between a texel and a 3D
point IS the UV map, and this walks it directly. So a pattern is written as a
function of POSITION, the one frame it is actually specified in, and nothing
has to model the animal's shape. No radius, no profile, no pole special case,
and it works identically on the body, the snout and the ears -- which the
inversion could never do.

IT IS ALSO WHAT THE REST OF THE WORLD DOES. Painting or baking a texture in
Blender or Substance and uploading it as a SurfaceAppearance map is the
ordinary Roblox pipeline; a procedural generator writing PNG bytes is the
unusual choice here. It was the right one for the spot and stripe packs, which
genuinely are sheet-space patterns, and those stay where they are.
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

import bpy, os, sys, math, array
from mathutils import Vector

from png_write import png, INK   # noqa: E402


SIZE = 1024
OUT = paths.skin_dir("animal")
MASKS = os.path.join(OUT, "masks")


# ---------------------------------------------------------------- the pattern
# THE BEE'S BANDS, WRITTEN IN THE FRAME THEY ARE ACTUALLY SPECIFIED IN.
#
# Rings perpendicular to the animal's LENGTH -- slices of a loaf, running over
# the back and under the belly from nose to tail. In Blender the pig's snout is
# at -Y and its tail at +Y, so a band is a range of Y and that is the whole
# definition. Compare the inverted version, which needed the body's radius
# profile, a crown fade and an eye keep-out to say the same thing.
#
# The numbers are in body units, where the body's own half-width is about 1.08,
# so they read directly against measured landmarks: the snout tip is at -1.38,
# the eyes at -0.89, the ears span -0.554..-0.164 and the tail is at +1.46.
#
# READ THEM AGAINST THE REFERENCE: a yellow face mask, a black band starting
# BEHIND the eyes -- so -0.62 has to sit back of -0.89, and it does -- a yellow
# band, a second black band, and a yellow rump the tail comes out of. The ears
# land inside the first band without being told to, which is the pattern being
# right rather than a rule being added for them.
# THE BEE'S BANDS, WRITTEN IN THE FRAME THEY ARE ACTUALLY SPECIFIED IN.
#
# Rings perpendicular to the animal's LENGTH -- slices of a loaf, running over
# the back and under the belly from nose to tail. In Blender the pig's snout is
# at -Y and its tail at +Y, so a band is a range of Y and that is the whole
# definition.
#
# The numbers are in body units. The body spans y -1.08 (nose end) to +1.05
# (rump), the eyes sit at -0.89, the ears span -0.554..-0.164 and the tail is
# at +1.46 -- so a first band starting at -0.62 is behind the eyes and the face
# stays clear, which is what the reference has.
#
# THIS IS A STARTING POINT FOR A BRUSH, NOT THE FINISHED ARTICLE. Three band
# tables were baked and photographed against the reference plush and none of
# them read as a bumblebee: bands solved purely as a function of Y cross the
# face and the crown as arcs, and the animal's own silhouette does the rest of
# the damage. What a bake is genuinely good for here is laying down rings that
# are geometrically true -- something a brush on a flat sheet cannot do at all
# -- and then the shaping is hand work in Texture Paint. See
# `skins/animal/masks/MASKS.md`.
BEE_BLACK = ((-0.62, -0.14), (0.34, 0.80))
BEE_EDGE = 0.045


def bee_alpha(bands=BEE_BLACK, edge=BEE_EDGE):
    """A band table -> the alpha function `bake` wants, as a CLOSURE rather
    than a module global: a run that bakes more than one table would otherwise
    have the second silently re-render the first."""
    def alpha(x, y, z):
        best = 0.0
        for lo, hi in bands:
            d = min(y - lo, hi - y)          # positive inside the band
            best = max(best, min(1.0, max(0.0, 0.5 + d / (2.0 * edge))))
        return best
    return alpha


# ---------------------------------------------------------------- the bake
# A RASTERISER RATHER THAN `bpy.ops.object.bake`, and the choice is worth
# stating. Cycles would bake this and needs the pattern expressed as a shader
# node graph -- and the patterns in this pack are Python functions with loops
# and lattices in them, which node graphs express badly. Walking the triangles
# keeps a pattern a PYTHON FUNCTION OF A 3D POINT, which is the readable half,
# and still inverts nothing.
#
# For every triangle: fill its UV footprint, and recover each texel's 3D point
# by barycentric interpolation of that triangle's own corners. Exact for a flat
# triangle, and the mesh is made of flat triangles.
def bake_positions(objs, size=SIZE, pad=6):
    """Where every texel of the sheet is in SPACE -- rasterised once, reused.

    THE SLOW HALF DOES NOT DEPEND ON THE PATTERN. Walking a million texels
    through Python barycentrics costs the same whether it is answering for a
    bee or for a leopard, so a run that compares four band tables should pay
    it ONCE. Splitting it out is also what makes a pattern trivially cheap to
    iterate on: change the numbers, re-evaluate, look -- no re-rasterise.
    """
    blank = bytes(4 * size * size)
    wx = array.array("f", blank)
    wy = array.array("f", blank)
    wz = array.array("f", blank)
    hit = bytearray(size * size)
    for ob in objs:
        me = ob.data
        me.calc_loop_triangles()
        uvl = me.uv_layers.active.data
        mw = ob.matrix_world
        for tri in me.loop_triangles:
            uvs = [Vector(uvl[l].uv) for l in tri.loops]
            pts = [mw @ me.vertices[v].co for v in tri.vertices]
            # THE SEAM FACES CARRY u ABOVE 1.0 ON PURPOSE -- `uv_cylinder`
            # pushes a wrapping face's low corners a whole turn rather than
            # smearing it, and texture REPEAT is what makes that render. For a
            # bake they have to come back inside the sheet or their texels land
            # off the edge and are simply lost. The whole TRIANGLE is shifted
            # by one turn, which keeps it continuous; wrapping each corner on
            # its own is the smear this exists to avoid.
            if max(q.x for q in uvs) > 1.0:
                uvs = [Vector((q.x - 1.0, q.y)) for q in uvs]
            xs = [q.x * size for q in uvs]
            ys = [q.y * size for q in uvs]
            x0 = max(0, int(math.floor(min(xs))) - 1)
            x1 = min(size - 1, int(math.ceil(max(xs))) + 1)
            y0 = max(0, int(math.floor(min(ys))) - 1)
            y1 = min(size - 1, int(math.ceil(max(ys))) + 1)
            ax, ay = xs[0], ys[0]
            bx, by = xs[1], ys[1]
            cx, cy = xs[2], ys[2]
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-12:
                continue
            # THE CORNERS COME OUT OF `Vector` BEFORE THE LOOP, AND THAT IS
            # MOST OF THE RUNTIME. `pts[0] * w0 + pts[1] * w1 + pts[2] * w2`
            # allocates five Vectors per TEXEL, about a million times -- the
            # first run of this took over fifteen minutes and wrote nothing,
            # which is indistinguishable from a hang. Interpolating three
            # floats costs nine multiplies and no allocation at all.
            p0x, p0y, p0z = pts[0].x, pts[0].y, pts[0].z
            p1x, p1y, p1z = pts[1].x, pts[1].y, pts[1].z
            p2x, p2y, p2z = pts[2].x, pts[2].y, pts[2].z
            inv = 1.0 / den
            for py in range(y0, y1 + 1):
                fy = py + 0.5
                rowbase = py * size
                for px in range(x0, x1 + 1):
                    fx = px + 0.5
                    w0 = ((by - cy) * (fx - cx) + (cx - bx) * (fy - cy)) * inv
                    w1 = ((cy - ay) * (fx - cx) + (ax - cx) * (fy - cy)) * inv
                    w2 = 1.0 - w0 - w1
                    # A SMALL NEGATIVE TOLERANCE RATHER THAN ZERO, so a texel
                    # sitting exactly on a shared edge is claimed by both
                    # triangles instead of by neither. At zero the sheet comes
                    # out stitched with unwritten hairlines along every seam.
                    if w0 < -0.002 or w1 < -0.002 or w2 < -0.002:
                        continue
                    i = rowbase + px
                    wx[i] = p0x * w0 + p1x * w1 + p2x * w2
                    wy[i] = p0y * w0 + p1y * w1 + p2y * w2
                    wz[i] = p0z * w0 + p1z * w1 + p2z * w2
                    hit[i] = 1
    # PADDING, BECAUSE A TEXEL THE MESH NEVER TOUCHED IS STILL SAMPLED.
    # Bilinear filtering reaches outside an island's edge, so an unwritten
    # texel beside a written one bleeds the background into the silhouette.
    # Nearest-written fill, a few rings out -- what every baker calls a margin.
    # SIX PASSES OVER A MILLION TEXELS IS SIX MILLION PYTHON ITERATIONS TO
    # GROW A SIX-PIXEL MARGIN. Only the texels still empty can ever grow, and
    # after the first pass that set only shrinks -- so it is carried rather
    # than rediscovered.
    empty = [i for i in range(size * size) if not hit[i]]
    for _ in range(pad):
        grow = []
        still = []
        for i in empty:
            y, x = divmod(i, size)
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                ny, nx = y + dy, x + dx
                j = ny * size + nx
                if 0 <= ny < size and 0 <= nx < size and hit[j]:
                    grow.append((i, j))
                    break
            else:
                still.append(i)
        empty = still
        for i, j in grow:
            wx[i], wy[i], wz[i] = wx[j], wy[j], wz[j]
            hit[i] = 1
    return (wx, wy, wz), hit


def shade(pos, hit, alpha_fn, size=SIZE):
    """A cached position buffer plus a pattern -> the alpha sheet.

    ONLY TEXELS THE MESH ACTUALLY REACHED ARE SHADED, and that is correctness
    before it is speed. An unwritten texel holds (0, 0, 0), which is a real
    point INSIDE the animal -- so shading it asks the pattern whether the
    origin is in a band, and for a table whose middle band straddles zero the
    answer is yes. The whole empty half of the sheet would come out WHITE:
    never sampled by the engine, and thoroughly confusing the first time
    somebody opens the mask in a paint program.

    The alpha function takes three floats rather than a `Vector` for the same
    reason the rasteriser does -- a million allocations to read one component.
    """
    wx, wy, wz = pos
    acc = [0.0] * (size * size)
    for i in range(size * size):
        if hit[i]:
            acc[i] = alpha_fn(wx[i], wy[i], wz[i])
    return acc


def bake(objs, alpha_fn, size=SIZE, pad=6):
    """The old one-shot signature, kept because it reads better for a single
    pattern and because nothing should have to know about the split."""
    pos, hit = bake_positions(objs, size, pad)
    return shade(pos, hit, alpha_fn, size), hit


def emit(path, acc, ink=INK, size=SIZE):
    rows = []
    for y in range(size):
        row = bytearray()
        base = y * size
        for x in range(size):
            a = acc[base + x]
            row += bytes((ink[0], ink[1], ink[2],
                          int(round(max(0.0, min(1.0, a)) * 255))))
        rows.append(bytes(row))
    png(path, rows, size, size, True)
    print("  %-28s %8d bytes  %dx%d"
          % (os.path.basename(path), os.path.getsize(path), size, size))


def emit_mask(path, acc, size=SIZE):
    """The same alpha as a GREYSCALE sheet, which is the hand-editable half.

    WHITE IS THE MARKING AND BLACK IS BARE SKIN -- the one convention the whole
    paint workflow rests on, and the reason a person authoring a pattern never
    has to think about colour. `make_paint_template.py --from-mask` turns one
    of these back into a map by writing the constant RGB and putting this in
    alpha, and the round trip is byte-identical.

    A BAKED PATTERN WRITES ITS MASK TOO, and that is not a convenience. The map
    and the mask are two views of one thing, and a generator that wrote only
    the map would leave the mask beside it describing whatever it described
    last time -- silently, since nothing compares them. Same shape as the
    published pile that disagreed with the real pig for want of one call.
    """
    rows = []
    for y in range(size):
        base = y * size
        row = bytearray()
        for x in range(size):
            v = int(round(max(0.0, min(1.0, acc[base + x])) * 255))
            row += bytes((v, v, v, 255))
        rows.append(bytes(row))
    png(path, rows, size, size, True)
    print("  %-28s %8d bytes  (mask)"
          % (os.path.basename(path), os.path.getsize(path)))


# THE BODY AND THE TRIM ARE BAKED INTO ONE SHEET, which the inversion could
# never have done. They share one cylinder over one height range, so a band at
# a given Y lands in the same place on the flank, the snout and the ears -- and
# the ears fall inside the first black band on their own geometry rather than
# because a keep-out was written for them.
def bake_bee():
    body = bpy.data.objects["Body"]
    trim = bpy.data.objects["Trim"]

    # THE LANDMARKS ARE MEASURED ON EVERY RUN RATHER THAN TRUSTED. Every number
    # in `BEE_BLACK` is a Y in body units, so they mean nothing without the
    # body's own extent -- and a band solved against a pig that has since been
    # regenerated is a stripe that has quietly slid off the rump.
    ys = [(body.matrix_world @ v.co).y for v in body.data.vertices]
    print("")
    print("  body spans y %+.3f (nose end) .. %+.3f (rump)" % (min(ys), max(ys)))
    for lo, hi in BEE_BLACK:
        print("    band %+.2f .. %+.2f   width %.2f" % (lo, hi, hi - lo))

    print("")
    print("=== BAKED PATTERNS ===")
    import time
    _t = time.time()
    pos, hit = bake_positions((body, trim))
    print("  rasterised in %.0fs" % (time.time() - _t), flush=True)
    print("  coverage: %d of %d texels written (%.1f%%)"
          % (sum(hit), SIZE * SIZE, 100.0 * sum(hit) / (SIZE * SIZE)))
    acc = shade(pos, hit, bee_alpha())
    emit(os.path.join(OUT, "pig_bands_color.png"), acc)
    emit_mask(os.path.join(MASKS, "bands.png"), acc)


if __name__ == "__main__":
    bpy.ops.wm.open_mainfile(filepath=paths.RAW)
    bake_bee()
