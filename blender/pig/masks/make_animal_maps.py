# -*- coding: utf-8 -*-
"""Author the animal maps: a shared FUR normal map and a STRIPE colour map.

    python make_animal_maps.py

WHY THE ANIMALS CAN HAVE WHAT THE METAL COULD NOT. A part wearing a
SurfaceAppearance is cut off from environment lighting -- measured, a roughness
sweep from 0.05 to 1.00 across the whole animal barely moves it and
`EnvironmentSpecularScale` 0.08 against 1.00 renders a pixel-identical frame.
That is fatal for a metal, which IS its reflections, and free for fur: fur is
diffuse. A NORMAL MAP perturbs the normal used for DIFFUSE shading, so it works
with no environment at all. The thing that killed gold cannot touch this.

BOTH MAPS TILE ALONG U, AND THAT IS NOT TIDINESS. U runs once around the animal,
so column 0 and column W-1 are neighbours on the pig -- a texture that does not
wrap shows a hard vertical line down one flank. Every noise lattice here is
wrapped modulo its own grid and every stripe centre is compared with a MODULAR
distance, so the two edges meet by construction rather than by luck.

WHAT U AND V MEAN HERE, because it decides what a pattern can be. The unwrap is
a cylinder about the pig's STANDING axis, so V is height and U is which way you
face. A pattern varying in V is a belt at a given height -- that is the metal
band overlay. A pattern varying in U is a set of bars running top to bottom,
spaced around the animal, which is what a tiger's flank stripes actually do.

THE STRIPE MAP IS BLACK ON TRANSPARENT, WHICH IS WHAT MAKES IT SHARED. Overlay
composites by the map's own alpha, so the gaps hand the tint back to the skin's
`Color3`: the same file is an orange tiger and a white zebra, and any other
black-marked animal somebody prices later.
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

import paths   # noqa: E402 -- the one place that knows the layout

import struct, zlib, os, math, sys

# The pig's own UV cylinder and measured radius profile -- one place decides
# both, and this file is the third reader. See pig_uv.py.
import pig_uv

from png_write import png, INK   # noqa: E402 -- one writer, one ink

OUT = paths.skin_dir("animal")
# 1024 IS ROBLOX'S CEILING FOR AN IMAGE ASSET AND THE FUR MAP NEEDS ALL OF IT.
# At 512 the fur's own octaves were UNDER-SAMPLED: the middle one runs at 320
# cells across the sheet, which is 1.6 pixels per cell -- BELOW THE TWO-PIXEL
# NYQUIST LIMIT, so it was aliasing into noise rather than resolving as grain,
# and the main octave at 160 was only 3.2. Doubling the sheet puts them at 3.2
# and 6.4, which is the first size at which the map draws what it describes.
#
# That is also the honest answer to "bake the real groom into it". At 512 the
# unwrap gives about 13 pixels per stud around the circumference and a strand
# is roughly 0.06 studs -- SUB-PIXEL -- so no bake could have resolved a strand
# either; it would have landed as noise, which is what is already there. The
# ceiling was the sheet, not the source.
SIZE = 1024


# ------------------------------------------------------------------ plumbing


def _hash(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 1442695040888963407) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def fade(t):
    return t * t * (3.0 - 2.0 * t)


def noise(u, v, fu, fv, seed):
    """Value noise on a lattice WRAPPED at (fu, fv), so it tiles in both axes."""
    x, y = u * fu, v * fv
    x0, y0 = int(math.floor(x)), int(math.floor(y))
    tx, ty = fade(x - x0), fade(y - y0)
    x0 %= fu; y0 %= fv
    x1, y1 = (x0 + 1) % fu, (y0 + 1) % fv
    a = _hash(x0, y0, seed); b = _hash(x1, y0, seed)
    c = _hash(x0, y1, seed); d = _hash(x1, y1, seed)
    return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty


# ------------------------------------------------------------- shared bits
# THE EYES GET A CLEAR PATCH ON EVERY PATTERN, AND THE COORDINATES ARE
# MEASURED RATHER THAN EYEBALLED. The unwrap is analytic, so the same
# arithmetic that built the UVs was run over the eye geometry: each eye lands
# at V 0.549..0.639, one at U 0.178..0.213 and the other at 0.287..0.322. A
# marking running through an eye is the one place a pattern stops reading as
# an animal.
#
# IT IS ALSO WHAT A REAL CAT HAS. The pale patch around the eye is a marking
# in its own right, so clearing the map here is not a hole cut to dodge a
# problem -- it is the face those markings are supposed to frame. Generous
# margins and a soft edge, because a hard-edged clearing reads as a sticker
# with a bite out of it.
#
# SHARED BY STRIPES AND SPOTS rather than copied into each. Two patterns with
# two copies of one eye position is the near-identical duplicate that drifts
# the first time an eye moves -- and the eye HAS moved once already, when the
# fur groom needed its real radius.
EYES = [(0.1955, 0.594), (0.3045, 0.594)]
EYE_RU, EYE_RV, EYE_FEATHER = 0.052, 0.082, 0.45

# HOW MANY STUDS A UNIT OF UV IS, WHICH IS NOT THE SAME ON BOTH AXES.
# `uv_cylinder` puts the whole circumference across u and the body's height
# across v, so from `Config.PIGGY_MESH` (12.00 x 11.52 x 12.79 studs):
U_STUDS = 38.96     # pi * the mean cross-section, across u = 0..1
V_STUDS = 13.98     # 11.52 studs of body over the 0.824 of v it occupies
# ONE STUD IS THEREFORE 2.79 TIMES AS MUCH v AS IT IS u. Stripes never had to
# care -- a bar has no height to distort -- but a circle drawn in UV space
# lands on the animal as an ellipse nearly three times taller than it is wide,
# so every spot radius below is authored in STUDS and converted per axis.


# WHERE THE BODY ACTUALLY SITS ON THE SHEET. `uv_cylinder` normalises V over
# the UNION of the body and the trim's world Z, so the BODY does not occupy
# the whole sheet -- measured off the exported UVs, it runs v 0.026 to 0.850
# and the rest is ears, legs and tail. Every correction below is expressed
# against the body's own span rather than against 0..1, which is what the
# first version got wrong.
BODY_V0, BODY_V1 = 0.026, 0.850

# THE CROWN IS A SINGULARITY AND NO WIDTH CORRECTION FIXES IT. A cylindrical
# unwrap collapses every value of u onto ONE POINT at the top of the animal,
# so the circumference there is zero and any pattern is stretched infinitely.
# Photographed from above in game, the leopard's spots came out as a radial
# STARBURST converging on the crown -- reported as "the spots near the top are
# distorted", which is exactly what it is.
#
# The girth term below helps everywhere else and cannot help here: dividing by
# a circumference that is going to zero just makes a spot wider until it wraps
# the whole animal. So the MARKINGS FADE OUT over the last stretch at each
# end, and what is left carrying those areas is the base colour and the grain
# -- and the grain is isotropic noise, whose smear reads as noise rather than
# as a defect.
#
# IT IS ALSO WHAT REAL ANIMALS LOOK LIKE, which is the reason to fade rather
# than to clamp. Markings thin out over the spine and a pale unmarked belly is
# nearly universal -- leopard, cheetah, deer and hyena all have one. The fix
# for a projection artefact happens to be the anatomy.
POLE_FADE = 0.15        # share of the body's own span faded at each end


def body_t(v):
    """Where up the BODY this row is, 0 at the belly and 1 at the crown."""
    return (v - BODY_V0) / (BODY_V1 - BODY_V0)


def pole_keep(v):
    """1 across the flanks, easing to 0 at the crown and the belly."""
    t = body_t(v)
    if t <= 0.0 or t >= 1.0:
        return 0.0
    if t < POLE_FADE:
        return fade(t / POLE_FADE)
    if t > 1.0 - POLE_FADE:
        return fade((1.0 - t) / POLE_FADE)
    return 1.0


def eye_keep(u, v, grow=1.0):
    """1 where a marking may be drawn, 0 over an eye, feathered between.

    `grow` WIDENS THE KEEP-OUT, AND IT EXISTS BECAUSE BOLDNESS COSTS THE FACE.
    The radii here were solved against the tiger, whose stripes are thin and
    pass either side of an eye without touching it. A zebra's bar is twice as
    wide, so at the same keep-out a single bar lands across the whole eye
    socket and the face stops reading -- the eye is the one feature every
    animal in this pack has to keep, and it is the first thing lost when a
    pattern is turned up.
    """
    keep = 1.0
    for (eu, ev) in EYES:
        du_e = abs(((u - eu + 0.5) % 1.0) - 0.5) / (EYE_RU * grow)
        dv_e = abs(v - ev) / (EYE_RV * grow)
        r = math.sqrt(du_e * du_e + dv_e * dv_e)
        if r < 1.0:
            t = 0.0 if r < 1.0 - EYE_FEATHER else (r - (1.0 - EYE_FEATHER)) / EYE_FEATHER
            keep = min(keep, fade(t))
    return keep


# ------------------------------------------------------------- the fur field
# ONE HEIGHT FIELD, READ BY BOTH CHANNELS. The strands are stretched along V,
# which is what makes it read as fur rather than as gravel: dense around the
# animal, coarse up it. Frequencies are integers so every octave tiles.
FUR_OCTAVES = [(160, 40, 1.00, 11), (320, 96, 0.30, 29), (96, 24, 0.35, 47)]


def fur_height(u, v):
    h = 0.0
    for fu, fv, amp, seed in FUR_OCTAVES:
        h += amp * noise(u, v, fu, fv, seed)
    return h


# THE GRAIN IS RETIRED AND THE FUNCTIONS ARE KEPT, WHICH IS WORTH EXPLAINING
# BECAUSE THE MEASUREMENT BELOW IS STILL CORRECT.
#
# It was built to answer a real finding -- the normal map cannot be seen, so
# the coat had to move into albedo -- and it worked: the body went from smooth
# plastic to a visible nap, verified in game. What retired it is a DIRECTION
# rather than a fault. Chasing a realistic coat was losing a race this engine
# cannot be won in, and the rest of this world is deliberately flat-shaded low
# poly with every textured material stripped out of it. A fine noise grain is
# the one thing on the pig arguing the other way, so the fur is a SHAPE now --
# `make_fur_tufts.py` -- and the maps are flat markings on flat colour.
#
# Kept rather than deleted because the finding underneath is reusable: if
# anything here ever wants surface detail again, this is the channel that
# works and the note below is why.
#
# ---------------------------------------------------------------------------
# THE COAT WAS IN THE COLOUR MAP, NOT THE NORMAL MAP, AND THAT WAS A
# MEASUREMENT RATHER THAN BELT AND BRACES.
#
# The normal map shipped first and the body read as smooth plastic in game --
# reported as "the body is not furry", with the spots on the SAME PIXEL
# looking right. The obvious suspect was `EnvironmentSpecularScale`, which
# this place holds at 0.08 on purpose and which is what made the metal pack
# read flat. Tested the only honest way -- one property, one object, one
# camera, 0.08 to 1.00 -- and THE BODY BARELY CHANGED. So the normal map is
# not being suppressed; it cannot be seen. The unwrap gives about 13 pixels
# per stud around the circumference, and shading that fine is gone by twenty
# studs.
#
# ALBEDO READS AND SHADING DOES NOT, on this pig at this distance, and the
# spots are the proof standing next to it. So the same field is emitted a
# second time as ALPHA over near-black: the shadow between strands, which is
# what fur looks like from across a street and what no amount of specular was
# going to give.
#
# DARKENING ONLY, NEVER LIGHTENING, which is what keeps it colour-blind. A
# pale grain would lerp toward a pale RGB and DESATURATE every base colour it
# lands on -- the trap the metal bands already hit, where white bands moved
# gold toward chrome. Darkening moves a colour down its own value axis and
# leaves the hue alone, so one grain serves a gold leopard, a grey snow
# leopard and a white dalmatian alike.
GRAIN_ALPHA = 0.26      # peak darkening, in the deepest crevice
GRAIN_GAMMA = 1.60      # pushes it to the dark end, so most of the sheet is
                        # untouched and the grain is shadow BETWEEN strands
                        # rather than an even wash over all of it
_grain_range = None


def grain_alpha(u, v):
    """How much this pixel is shaded by the fur standing on it."""
    global _grain_range
    if _grain_range is None:
        # SAMPLED RATHER THAN ASSUMED. The octave amplitudes sum to 1.65, but
        # three noise fields never peak together, so using that as the range
        # would leave the grain permanently pale.
        lo = hi = fur_height(0.5, 0.5)
        for i in range(8192):
            uu = ((i * 7919) % 4096) / 4096.0
            vv = ((i * 104729) % 4096) / 4096.0
            h = fur_height(uu, vv)
            lo = min(lo, h); hi = max(hi, h)
        _grain_range = (lo, max(hi, lo + 1e-6))
    lo, hi = _grain_range
    t = max(0.0, min(1.0, (fur_height(u, v) - lo) / (hi - lo)))
    return GRAIN_ALPHA * ((1.0 - t) ** GRAIN_GAMMA)


def over(under, above):
    """Composite two alphas of the SAME ink, in the right order.

    Not a max() and not a sum: two washes of one ink give
    `1 - (1-a)(1-b)`. A max() would lose the grain everywhere a marking sits,
    leaving the markings flat against a furry background.
    """
    return 1.0 - (1.0 - under) * (1.0 - above)


# ---------------------------------------------------------------------- fur
def build_fur():
    """A height field of fine strands, turned into a tangent-space normal map.

    THE STRANDS ARE STRETCHED ALONG V, which is what makes it read as fur
    rather than as gravel: the lattice is dense around the animal (many
    strands side by side) and coarse up it (each strand is long). Octaves are
    integer frequencies so every one of them tiles.
    """
    # SLOPE, NOT "STRENGTH", AND THE FIRST VERSION CONFUSED THE TWO. A number
    # multiplied straight onto a noise gradient is meaningless: the gradient of
    # this field runs to roughly the sum of amplitude x frequency, about 340,
    # so a "strength" of 2.6 tilted every normal almost flat to the surface and
    # the pig rendered as crumpled tin foil. What matters is the SLOPE the
    # normal ends up at, so the gradients are measured and then scaled so the
    # steepest lands at MAX_SLOPE. Fur on a twelve-stud animal is a texture you
    # notice without looking at it; 0.35 is a gentle nap rather than gravel.
    MAX_SLOPE = 0.35
    height = fur_height

    d = 1.0 / SIZE
    # PASS ONE: measure the field's own gradients, so the scale is derived
    # from what the noise actually does rather than typed.
    grads = []
    for y in range(SIZE):
        v = (y + 0.5) / SIZE
        line = []
        for x in range(SIZE):
            u = (x + 0.5) / SIZE
            hu = (height((u + d) % 1.0, v) - height((u - d) % 1.0, v)) / (2 * d)
            hv = (height(u, min(1.0, v + d)) - height(u, max(0.0, v - d))) / (2 * d)
            line.append((hu, hv))
        grads.append(line)
    mags = sorted(math.hypot(a, b) for line in grads for a, b in line)
    # the 99th percentile rather than the maximum: one freak pixel must not
    # set the scale for the whole map
    ref = mags[int(len(mags) * 0.99)] or 1.0
    k = MAX_SLOPE / ref

    rows = []
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            hu, hv = grads[y][x]
            nx, ny, nz = -hu * k, -hv * k, 1.0
            L = math.sqrt(nx * nx + ny * ny + nz * nz)
            row += bytes((
                max(0, min(255, int((nx / L) * 0.5 * 255 + 127.5))),
                max(0, min(255, int((ny / L) * 0.5 * 255 + 127.5))),
                max(0, min(255, int((nz / L) * 0.5 * 255 + 127.5))),
                255))
        rows.append(bytes(row))
    print("  fur: 99th-percentile gradient %.1f, scaled to a max slope of %.2f"
          % (ref, MAX_SLOPE))
    return rows


# ------------------------------------------------------------------ stripes
def build_stripes():
    """Tapered, wobbling vertical bars -- black where they are, clear elsewhere.

    A REAL STRIPE IS NOT A RECTANGLE, which is the whole difference from the
    part-built version this replaces. Three things are varied per stripe and
    each is one of the tells: the centre WOBBLES down the body, the width
    TAPERS to nothing at the ends so a stripe has points rather than blunt
    cuts, and every stripe gets its own seed so no two are the same bar.
    """
    N = 15                      # stripes around the animal; integer, so it tiles
    ALPHA = 0.94
    rows = []
    for y in range(SIZE):
        v = (y + 0.5) / SIZE
        row = bytearray()
        for x in range(SIZE):
            u = (x + 0.5) / SIZE
            best = 0.0
            for i in range(N):
                seed = 100 + i * 7
                centre = (i + 0.5) / N + (noise(v, 0.5, 8, 2, seed) - 0.5) * 0.055
                # modular distance: the two edges of the sheet are neighbours
                du = abs(((u - centre + 0.5) % 1.0) - 0.5)
                # taper: full width across the flank, pinched top and bottom
                span = 0.30 + 0.62 * math.sin(math.pi * min(1.0, max(0.0, (v - 0.03) / 0.94)))
                w = (0.0125 + 0.020 * noise(v * 1.7, 0.25, 6, 3, seed + 3)) * span
                if w <= 0.0:
                    continue
                edge = w * 0.34
                if du < w:
                    a = 1.0 if du < w - edge else (w - du) / max(edge, 1e-6)
                    best = max(best, a)
            keep = eye_keep(u, v) * pole_keep(v)
            a = max(0.0, min(1.0, best)) * keep * ALPHA
            row += bytes((14, 12, 14, int(round(a * 255))))
        rows.append(bytes(row))
    return rows


# -------------------------------------------------------------------- spots
def build_spots():
    """Irregular rosettes on a jittered lattice -- leopard rather than polka.

    THE SAME CONVENTION AS THE STRIPES, WHICH IS WHAT MAKES IT A SEPARABLE
    LAYER: near-black RGB with the pattern in the ALPHA, so `AlphaMode.Overlay`
    composites it over whatever `Color3` the skin carries. One file is a gold
    leopard, a grey snow leopard and a white dalmatian.

    THREE THINGS STOP IT READING AS POLKA DOTS, and all three are the same
    idea -- a real coat is not a grid of circles.

    A JITTERED LATTICE rather than a random scatter. Pure random clumps and
    leaves bald patches (the Poisson problem the fur groom already ran into);
    a lattice with each spot nudged inside its own cell keeps the spacing
    even and the arrangement irregular. It also TILES in u for free, because
    the columns divide the circumference exactly.

    A WOBBLED RADIUS. Each spot's edge is modulated by two sine terms at its
    own phase, so no two are the same shape and none is a circle.

    AND THE STUD CORRECTION, twice. Radii are authored in studs and converted
    per axis, so a spot is round on the ANIMAL rather than round in the map --
    and u is widened toward the poles, because the cylindrical unwrap puts the
    same amount of u across a shrinking cross-section, which would otherwise
    squeeze every spot on the back and belly into a vertical slot.
    """
    NU, NV = 18, 7              # columns around, rows down; NU divides u so it tiles
    ALPHA = 0.94
    R_STUDS = 0.62              # mean spot RADIUS on the animal
    FEATHER = 0.24              # share of the radius spent on the soft edge

    rows = []
    for y in range(SIZE):
        v = (y + 0.5) / SIZE
        # how much of the circumference is actually here. A cylinder unwrap
        # spends the same u on a small cross-section as on a big one, so
        # without this a spot near the crown is a third of its proper width.
        # HOW MUCH CIRCUMFERENCE IS ACTUALLY HERE. This was `sin(pi * v)`,
        # which measures up the SHEET rather than up the BODY -- so at the
        # crown (v 0.850) it returned 0.454 where the true girth is nearly
        # zero, and the correction was barely a third of what it should be.
        girth = max(0.30, math.sin(math.pi * min(1.0, max(0.0, body_t(v)))))
        row = bytearray()
        for x in range(SIZE):
            u = (x + 0.5) / SIZE
            best = 0.0
            cu, cv = u * NU, v * NV
            ci, cj = int(math.floor(cu)), int(math.floor(cv))
            for di in (-1, 0, 1):
                for dj in (-1, 0, 1):
                    i, j = (ci + di) % NU, cj + dj
                    if j < 0 or j >= NV:
                        continue
                    su = (i + 0.30 + 0.40 * _hash(i, j, 11)) / NU
                    sv = (j + 0.30 + 0.40 * _hash(i, j, 23)) / NV
                    rs = R_STUDS * (0.72 + 0.56 * _hash(i, j, 37))
                    # studs from this spot's centre, on each axis
                    du = ((u - su + 0.5) % 1.0 - 0.5) * U_STUDS * girth
                    dv = (v - sv) * V_STUDS
                    d = math.sqrt(du * du + dv * dv)
                    if d > rs * 1.4:
                        continue
                    ang = math.atan2(dv, du)
                    ph = _hash(i, j, 53) * math.tau
                    wob = 1.0 + 0.17 * math.sin(3.0 * ang + ph)                               + 0.09 * math.sin(5.0 * ang + ph * 1.7)
                    reff = rs * wob
                    if d >= reff:
                        continue
                    edge = reff * FEATHER
                    a = 1.0 if d < reff - edge else (reff - d) / max(edge, 1e-6)
                    best = max(best, a)
            a = max(0.0, min(1.0, best)) * eye_keep(u, v) * pole_keep(v) * ALPHA
            row += bytes((14, 12, 14, int(round(a * 255))))
        rows.append(bytes(row))
    return rows


# ----------------------------------------------------------------- plain fur
def build_fur_color():
    """The coat with no markings on it -- the base animal.

    The fur is the DEFAULT layer and a pattern is the separable one, so the
    plain skin needs a ColorMap of its own rather than an empty slot. It is
    exactly the grain the other two carry underneath their markings.
    """
    rows = []
    for y in range(SIZE):
        v = (y + 0.5) / SIZE
        row = bytearray()
        for x in range(SIZE):
            u = (x + 0.5) / SIZE
            row += bytes((14, 12, 14, int(round(grain_alpha(u, v) * 255))))
        rows.append(bytes(row))
    return rows


# ==========================================================================
# THE REST OF THE PACK
# ==========================================================================
# Every one of these emits the SAME near-black ink with the shape in the
# ALPHA, so the skin's own Color3 is the animal and one generator serves
# every colourway of it. The single exception is the orca, and its reason is
# written on it.
#
# They all take `eye_keep` and `pole_keep` for free, which is the point of
# those being shared: a new pattern cannot forget to clear the eyes or to
# fade at the crown, because it never had the chance to write that code.



def _emit(alpha_fn, ink=INK, eye_grow=1.0, pole=True):
    """Walk the sheet once and build the rows.

    Every pattern is this plus a function, which is what keeps six of them
    from being six pipelines. `eye_grow` is passed through rather than being
    a constant so a bold pattern cannot forget to clear the face -- see
    `eye_keep`.

    `pole` TURNS OFF THE CROWN FADE, AND ONLY ONE PATTERN MAY DO IT. That fade
    exists because a marking laid out in U SMEARS at the crown: every
    longitude collapses onto one point there, so a spot or a stripe arrives as
    a spray of wedges. A pattern laid out in the front-back axis has the
    opposite property -- its bands CROSS the crown as clean lines, which is
    where the reference shows them at their boldest -- so fading them out
    there deletes the part of the pattern a player looking down at the pig
    actually sees. See `build_bands`.
    """
    rows = []
    for y in range(SIZE):
        v = (y + 0.5) / SIZE
        row = bytearray()
        for x in range(SIZE):
            u = (x + 0.5) / SIZE
            a = alpha_fn(u, v) * eye_keep(u, v, eye_grow)
            if pole:
                a *= pole_keep(v)
            row += bytes((ink[0], ink[1], ink[2],
                          int(round(max(0.0, min(1.0, a)) * 255))))
        rows.append(bytes(row))
    return rows


def _girth(v):
    return max(0.30, math.sin(math.pi * min(1.0, max(0.0, body_t(v)))))


def _round_spots(u, v, NU, NV, r_studs, vary, wobble, feather, alpha):
    """Spots on a jittered lattice, sized in STUDS so they come out round on
    the animal rather than round on the sheet."""
    g = _girth(v)
    best = 0.0
    ci, cj = int(math.floor(u * NU)), int(math.floor(v * NV))
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            i, j = (ci + di) % NU, cj + dj
            if j < 0 or j >= NV:
                continue
            su = (i + 0.28 + 0.44 * _hash(i, j, 11)) / NU
            sv = (j + 0.28 + 0.44 * _hash(i, j, 23)) / NV
            rs = r_studs * (1.0 - vary + 2.0 * vary * _hash(i, j, 37))
            du = ((u - su + 0.5) % 1.0 - 0.5) * U_STUDS * g
            dv = (v - sv) * V_STUDS
            d = math.hypot(du, dv)
            if d > rs * 1.6:
                continue
            reff = rs
            if wobble > 0.0:
                ang = math.atan2(dv, du)
                ph = _hash(i, j, 53) * math.tau
                reff = reff * (1.0 + wobble * math.sin(3.0 * ang + ph)
                               + wobble * 0.5 * math.sin(5.0 * ang + ph * 1.7))
            if d >= reff:
                continue
            edge = reff * feather
            best = max(best, 1.0 if d < reff - edge
                       else (reff - d) / max(edge, 1e-6))
    return best * alpha


# ------------------------------------------------------------------ ladybug
def build_dots_big():
    """Few, large, genuinely ROUND spots.

    The one pattern here that is not organic. A ladybug has about seven spots
    and they are near-circles, so wobble is ZERO -- where every mammal in this
    file needs it to stop reading as polka dots.
    """
    return _emit(lambda u, v: _round_spots(u, v, NU=4, NV=3, r_studs=1.65,
                                           vary=0.14, wobble=0.0,
                                           feather=0.16, alpha=0.96))


# ---------------------------------------------------------------------- cow
def build_blotches():
    """Very large irregular patches, from a noise THRESHOLD rather than from
    placed shapes.

    A cow's markings have no repeating unit at all -- they are continents with
    coastlines -- and a lattice of blobs always reads as a lattice however
    hard it is jittered. Thresholding a coarse field is the only thing that
    gives edges with bays and headlands in them.
    """
    def a(u, v):
        n = (1.00 * noise(u, v, 6, 4, 71)
             + 0.45 * noise(u, v, 13, 8, 83)
             + 0.20 * noise(u, v, 27, 16, 97)) / 1.65
        return max(0.0, min(1.0, (n - 0.50) / 0.055)) * 0.96
    return _emit(a)


# -------------------------------------------------------------------- bars
def _bars(u, v, N, w_lo, w_hi, wobble, edge_share, alpha, seed0,
          span_lo=0.34, span_hi=0.94):
    """Vertical bars around the animal.

    `span_lo`/`span_hi` ARE THE TAPER, AND THEY ARE THE DIFFERENCE BETWEEN THE
    TWO ANIMALS THAT USE THIS. A bar is scaled by `span`, which runs from
    `span_lo` at the belly and the crown to `span_hi` at the widest part of
    the flank. On a tiger that is most of the character -- its stripes are
    brush strokes that come to a POINT at both ends, so 0.34 to 0.94 is a
    2.8:1 taper and each bar is a lens. A zebra's are BANDS: near enough
    parallel-sided, wrapping the body like a hoop, so it wants that ratio
    close to 1 or every stripe reads as a leaf.

    The defaults are the tiger's, so the animal this was written for is
    untouched by the parameter existing.
    """
    best = 0.0
    for i in range(N):
        seed = seed0 + i * 7
        centre = (i + 0.5) / N + (noise(v, 0.5, 8, 2, seed) - 0.5) * wobble
        du = abs(((u - centre + 0.5) % 1.0) - 0.5)
        span = span_lo + (span_hi - span_lo) * math.sin(
            math.pi * min(1.0, max(0.0, body_t(v))))
        w = (w_lo + (w_hi - w_lo) * noise(v * 1.7, 0.25, 6, 3, seed + 3)) * span
        if w <= 0.0:
            continue
        e = w * edge_share
        if du < w:
            best = max(best, 1.0 if du < w - e else (w - du) / max(e, 1e-6))
    return best * alpha


def build_stripes_bold():
    """A zebra is not a thin tiger.

    SEVEN bars against the tiger's fifteen, and about half as wide again.
    The first pass used nine at 0.026-0.040 and read as pinstripes beside a
    real zebra -- reference plush zebras carry markings that are BOLD AND FEW.

    AND THE CORRECTION AFTER THAT ONE OVERSHOT, WHICH IS THE HALF WORTH
    KEEPING. Widened to 0.045-0.062 with the wobble pushed to 0.055, adjacent
    bars MERGED: the widest span multiplier is 0.94, so at the flank a bar
    reaches 0.058 of the circumference against a spacing of 0.143, and two
    neighbours wandering 0.055 toward each other close a gap of 0.027. What
    came out was not a bolder zebra, it was black continents on white -- no
    rhythm, no countable stripes, and a reference plush is BOLD AND ORDERED
    rather than bold and chaotic. 0.034-0.046 with the wobble back at 0.035 is
    the midpoint, and it keeps a clear white lane between every pair.

    AND THEN WIDTH TURNED OUT TO BE THE WRONG DIAL ENTIRELY. Three passes went
    into how WIDE a bar is -- pinstripes at 0.026, blobs at 0.046, a workable
    0.040 -- and all three were tuning the wrong number, because `N` is a
    count around the WHOLE animal and only half of it is ever in frame. At
    seven bars a viewer sees THREE AND A HALF, so each one has to be enormous
    to cover the flank at all, and an enormous stripe on a round body is a
    black continent however cleanly its edges are drawn. A reference plush
    zebra shows eight to ten down one side.

    So the count went to ELEVEN and the width came down with it, holding the
    ratio that was already right. What actually reads as a zebra is
    BAR-TO-GAP, not bar width: roughly equal black and white. At 0.025 against
    a spacing of 0.0909 a bar covers 52% of its pitch, which is the same 52%
    the seven-bar version had -- the same animal drawn at the right scale
    rather than a different one.

    THE MERGE TEST STILL HAS TO PASS: `2 * w_hi * span_hi + wobble < 1 / N`.
    Here that is 0.0555 against 0.0909, so 39% of the pitch survives as white
    at the widest point. `du` is a distance from the CENTRE, so `w` is a
    HALF-width and a bar is `2w` across -- the correction that got missed the
    first time this was checked.

    THE TAPER IS NEARLY OFF, which is the other half of not being a tiger.
    0.62 to 0.98 is a 1.6:1 lens against the tiger's 2.8:1, so a stripe stays
    a band from the back down to the belly instead of pinching to a point in
    the middle of the flank.

    The edge is harder than the tiger's (0.16 against 0.22): a zebra has crisp
    boundaries where a tiger fades into its own orange. The eye keep-out is
    grown because a bar this bold would otherwise cross the socket.
    """
    return _emit(lambda u, v: _bars(u, v, N=11, w_lo=0.019, w_hi=0.025,
                                    wobble=0.008, edge_share=0.16,
                                    alpha=0.98, seed0=200,
                                    span_lo=0.62, span_hi=0.98),
                 eye_grow=1.35)


# ---------------------------------------------------------------------- bee
# A BEE'S BANDS RUN AROUND THE NOSE-TO-TAIL AXIS, NOT AROUND THE STANDING
# ONE, AND GETTING THAT WRONG IS WHAT MADE THE FIRST FOUR PASSES A JUMPER.
#
# Every other pattern in this pack is laid out in the sheet's own coordinates:
# spots at a (u, v) lattice, stripes at constant u, hoops at constant v. Hoops
# at constant v are HORIZONTAL RINGS -- they circle the pig's waist, stacked up
# its height -- and that is a hooped jumper. A reference bumblebee's bands are
# rings perpendicular to the animal's LENGTH: slices of a loaf, running over
# the back and under the belly, marching from the nose to the tail. No amount
# of retuning a count or a duty cycle turns one into the other; they are
# different axes.
#
# AND IT NEEDS NO NEW GEOMETRY, BECAUSE THE UNWRAP CAN BE INVERTED. The map is
# sampled by (u, v) and the band wants to know the front-back coordinate y, so
# the question is whether y can be recovered from a texel. On this cylinder it
# can, exactly:
#
#     u is the angle about the standing axis, so theta = (u - 0.5) * tau
#     v is height, and `pig_uv.body_radius` is how wide the pig is there
#     y = r * sin(theta)
#
# Verified against the real mesh: the snout's tip measures u 0.250 (theta
# -pi/2, so y = -r, the front) and the tail's measures u 0.740, which is what
# those two directions have to be if the inversion is right.
#
# THE RADIUS HAS TO BE MEASURED AND THE FIRST BUILD MODELLED IT, WHICH IS WHAT
# MADE THE BANDS SWIRL. `sin(pi * body_t(v))` is exact for a circle when t is
# the ANGULAR parameter and `body_t` is linear in HEIGHT -- different
# functions, and the sine runs 55% low at t = 0.10. Read as "the pig is very
# narrow here", so the front-back coordinate collapsed toward zero at the
# crown and the belly and every ring bowed inward into a swirl. The profile
# lives in `pig_uv.BODY_RADIUS`, sampled off the mesh.
#
# WHERE IT BREAKS IS THE TRIM, AND THAT IS WHY THE TRIM HAD TO SPLIT. The
# radius model is the BODY's, so anything standing off the body at a height
# where the body is narrow gets the body's radius rather than its own: the
# ears sit near the crown, where sin(pi t) is nearly zero, so this function
# puts them at y = 0 when they are really at y = -0.49 and squarely inside the
# first black band. One map cannot know which part it is being read on. The
# snout, the ears, the legs and the tail take flat colours instead.

# The bands, as front-back coordinates in body units -- the body's own
# horizontal radius is 1.0, so these are directly comparable to the measured
# geometry: the snout tip is at -1.38, the eyes at -0.89, the ears at -0.49
# and the tail at +1.46.
#
# READ THEM AGAINST THE REFERENCE: a yellow face mask, a black band starting
# BEHIND the eyes (so -0.62 has to sit back of -0.89, and it does), a yellow
# band, a second black band, and a yellow rump the tail comes out of.
BEE_BLACK = ((-0.62, -0.14), (0.34, 0.80))
BEE_EDGE = 0.045        # softness at a boundary, in the same units


def build_bands():
    """Rings around the animal's LENGTH -- see the block above.

    THE CROWN FADE IS OFF FOR THIS ONE PATTERN. Every other map here is laid
    out in U and smears where the longitudes converge, which is what the fade
    is for. These bands CROSS the crown as clean lines -- geometrically, a
    ring at y = -0.3 passes over the top of the sphere at z = 0.954 -- and the
    top of the pig is exactly where the reference shows them boldest.

    NO EYE KEEP-OUT EITHER, AND THAT IS THE PATTERN BEING RIGHT RATHER THAN
    THE CHECK BEING SKIPPED. The eyes sit at y -0.89, forward of the first
    band's -0.62, so they are inside the yellow face mask by a quarter of a
    body radius. The hooped version needed the widest keep-out in the pack
    precisely because a horizontal ring has no gaps for a face to sit in; this
    one has the face in a gap by construction.
    """
    def a(u, v):
        t = min(1.0, max(0.0, body_t(v)))
        # MEASURED, NEVER MODELLED -- this is the line that was the swirl.
        r = pig_uv.body_radius(t)
        y = r * math.sin((u - 0.5) * math.tau)
        best = 0.0
        for lo, hi in BEE_BLACK:
            # how far INSIDE the band this texel is; negative outside
            d = min(y - lo, hi - y)
            best = max(best, min(1.0, max(0.0, 0.5 + d / (2.0 * BEE_EDGE))))
        return best * 0.98
    return _emit(a, pole=False)


# ------------------------------------------------------------------ giraffe
def build_patches():
    """Polygonal patches with thin pale lanes between them -- a VORONOI.

    The only pattern in the pack defined by its GAPS rather than by its
    shapes. Taking the difference between the nearest and second-nearest cell
    centre gives that for free: near a border the two are equal, so the
    difference falls to zero and the lane appears without being drawn.
    """
    NU, NV = 9, 6

    def a(u, v):
        g = _girth(v)
        ci, cj = int(math.floor(u * NU)), int(math.floor(v * NV))
        d1 = d2 = 1e9
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                i, j = (ci + di) % NU, cj + dj
                if j < 0 or j >= NV:
                    continue
                su = (i + 0.18 + 0.64 * _hash(i, j, 131)) / NU
                sv = (j + 0.18 + 0.64 * _hash(i, j, 137)) / NV
                du = ((u - su + 0.5) % 1.0 - 0.5) * U_STUDS * g
                dv = (v - sv) * V_STUDS
                d = math.hypot(du, dv)
                if d < d1:
                    d1, d2 = d, d1
                elif d < d2:
                    d2 = d
        lane = 0.62
        return max(0.0, min(1.0, (d2 - d1) / lane)) * 0.95
    return _emit(a)


# --------------------------------------------------------------------- orca
def build_orca():
    """THE ONE INVERTED MAP, AND IT BREAKS THE PACK'S CONVENTION ON PURPOSE.

    Every other pattern is dark ink over a light base. An orca is the other
    way round -- a near-black animal with a few large WHITE marks -- so this
    map's RGB is white and the skin's body colour supplies the dark. Config
    already calls it "the one inverted animal in the bucket"; this is that
    sentence written as a texture.

    IT IS ALSO THE ONLY PLACED PATTERN, and that is why it gets its own
    generator rather than a parameter. A scatter of white blobs is a cow in a
    dinner jacket. What makes an orca is three specific marks: a pale belly,
    an oval behind each eye, and a saddle over each flank -- so they are
    written as shapes at measured coordinates.

    NO POLE FADE EITHER. That fade exists because a pattern smears at the
    crown; the belly mark IS the bottom of the animal and fading it out is
    fading out the thing itself.
    """
    EYE_U = (0.1955, 0.3045)

    def a(u, v):
        t = body_t(v)
        best = max(0.0, min(1.0, (0.30 - t) / 0.10))
        for eu in EYE_U:
            du = abs(((u - (eu + 0.035) + 0.5) % 1.0) - 0.5) / 0.045
            dv = (v - 0.625) / 0.055
            r = math.hypot(du, dv)
            best = max(best, max(0.0, min(1.0, (1.0 - r) / 0.35)))
        for su in (0.02, 0.48):
            du = abs(((u - su + 0.5) % 1.0) - 0.5) / 0.085
            dv = (v - 0.700) / 0.075
            r = math.hypot(du, dv)
            best = max(best, max(0.0, min(1.0, (1.0 - r) / 0.45)))
        return best * 0.95

    rows = []
    for y in range(SIZE):
        v = (y + 0.5) / SIZE
        row = bytearray()
        for x in range(SIZE):
            u = (x + 0.5) / SIZE
            al = a(u, v) * eye_keep(u, v)
            row += bytes((246, 248, 252,
                          int(round(max(0.0, min(1.0, al)) * 255))))
        rows.append(bytes(row))
    return rows


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, rows, rgba in (("pig_fur_normal.png", build_fur(), True),
                             ("pig_stripes_color.png", build_stripes(), True),
                             ("pig_spots_color.png", build_spots(), True),
                             ("pig_dots_big_color.png", build_dots_big(), True),
                             ("pig_blotches_color.png", build_blotches(), True),
                             ("pig_stripes_bold_color.png", build_stripes_bold(), True),
                             ("pig_bands_color.png", build_bands(), True),
                             ("pig_patches_color.png", build_patches(), True),
                             ("pig_orca_color.png", build_orca(), True)):
        p = os.path.join(OUT, name)
        png(p, rows, SIZE, SIZE, rgba)
        made.append((name, os.path.getsize(p)))
    print("")
    print("=== ANIMAL MAPS ===")
    for n, sz in made:
        print("  %-24s %8d bytes   %dx%d" % (n, sz, SIZE, SIZE))
    print("")
    print("  fur     -> NormalMap, shared by every animal skin, no per-animal art")
    print("  stripes -> ColorMap, black on transparent, so the skin's own")
    print("             Color3 shows between the bars (tiger orange, zebra white)")
    print("  spots   -> ColorMap, the same convention: leopard, cheetah,")
    print("             dalmatian and snow leopard are one file and four colours")


# GUARDED, BECAUSE THIS MODULE IS ALSO A LIBRARY AND A BARE `main()` MADE IT A
# BOMB. `bake_pattern.py` imports two names from here -- one PNG writer and one
# ink colour, deliberately, so there is one of each rather than two -- and an
# unguarded call meant that import REGENERATED ALL NINE 1024-square maps in
# pure Python and rewrote `skins/` as a side effect of asking for a constant.
#
# It presented as a hang rather than as slowness: a run wrote nothing for
# fifteen minutes, twice, while looking exactly like a slow bake -- and the
# work it was doing was work nobody had asked for and whose output was thrown
# away. `make_paint_template.py` had already noticed and worked around it,
# choosing to COPY the four constants with a comment saying importing "is not
# available: that module runs a build on import". It is available now.
#
# Running the file as a script is unchanged.
if __name__ == "__main__":
    main()
