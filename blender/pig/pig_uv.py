# -*- coding: utf-8 -*-
"""The pig's shared UV cylinder -- the one place its height range is decided.

WHY THIS IS A FILE RATHER THAN A CONSTANT IN THREE SCRIPTS.

Every part of this animal is unwrapped on ONE cylinder about the standing
axis: u is the angle, v is world height normalised over a shared range. That
range is what makes a marking at a given height land in the same place on the
snout, the ears, the legs and the flank -- which is the whole reason a single
pattern map can dress a whole pig.

`build_pig.py` sets it, `make_fur_tufts.py` copies it so the tufts wear the
same map, and `make_animal_shapes.py` copies it again. Three copies of one
number, and this project has already paid for that shape more than once: the
road width that drifted between two files, the ride-key grammar that broke
within the hour of being duplicated, `SUNK` read by two halves of one shop.

IT IS PINNED RATHER THAN MEASURED, WHICH IS THE ACTUAL FEATURE.

Derived from the current bounding box, the range moves whenever the animal's
height moves -- so adjusting an ear or a tail shifts v for the WHOLE pig, and
every pattern map, every V coordinate in `make_animal_maps.py` (the eye
centres, the body band, the pole fade) is silently offset with it. Nothing
errors; a leopard's spots simply creep.

Pinned, a geometry edit is FREE: the changed part is unwrapped on the same
cylinder, lands at the same v, and every existing map still fits. That is the
difference between "I can adjust the nose" and "I can adjust the nose and know
nothing else moved".

TO CHANGE IT DELIBERATELY: move the numbers here, then rebuild every map in
`make_animal_maps.py` AND re-derive its V constants against the new range.
It is one edit and nine textures, which is exactly why it should be a
decision rather than a side effect.
"""

# Measured on the shipped pig (Body + Trim, world Z). Pinning them at the
# measured values changes not one UV, so this cost no re-bake to introduce.
UV_Z0 = -1.020000
UV_SPAN = 2.328977

# Blender units, about a hundredth of a stud -- under this, a difference is
# float noise rather than a change to the animal.
UV_DRIFT_WARN = 0.002


def uv_v(world_z):
    """World height -> v on the shared sheet."""
    return (world_z - UV_Z0) / UV_SPAN


def check_drift(objs, label="uv"):
    """Measure what the range WOULD be and report when it has moved.

    Deliberately does not change anything. The pinned range is what the
    unwrap runs on; this exists so a real change to the animal's height is
    announced rather than quietly re-registering every texture in the pack.
    Returns True when the pinned range still describes the geometry.
    """
    zs = []
    for ob in objs:
        for v in ob.data.vertices:
            zs.append((ob.matrix_world @ v.co).z)
    if not zs:
        return True
    z_meas, span_meas = min(zs), (max(zs) - min(zs)) or 1.0
    d0, d1 = abs(z_meas - UV_Z0), abs(span_meas - UV_SPAN)
    if d0 > UV_DRIFT_WARN or d1 > UV_DRIFT_WARN:
        print("")
        print("  *** UV RANGE DRIFT (%s) ***" % label)
        print("  measured z0 %.6f span %.6f" % (z_meas, span_meas))
        print("  pinned   z0 %.6f span %.6f" % (UV_Z0, UV_SPAN))
        print("  The pig's height has changed. The unwrap is still running on")
        print("  the PINNED range, so every existing pattern map still fits --")
        print("  which is the point. Re-pin in pig_uv.py ONLY if you also mean")
        print("  to rebuild make_animal_maps.py's V constants and every map.")
        return False
    print("  %s: pinned range z0 %.6f span %.6f (drift %.5f / %.5f)"
          % (label, UV_Z0, UV_SPAN, d0, d1))
    return True


# ==========================================================================
# THE BODY'S OWN RADIUS PROFILE
# ==========================================================================
# HOW WIDE THE PIG IS AT A GIVEN HEIGHT, MEASURED OFF THE MESH RATHER THAN
# MODELLED -- and the difference is not a rounding, it is the whole shape.
#
# A pattern that has to know where a texel sits FRONT-TO-BACK has to invert
# the cylinder: u gives the angle, and the horizontal radius at that height
# turns the angle into a coordinate. The bee's bands are the first pattern to
# need it, and the first model tried was `sin(pi * t)` -- exact for a circle
# IF t is the angular parameter, and this project's `body_t` is LINEAR IN
# HEIGHT. Those are different functions and nothing says so:
#
#     t      measured    sin(pi t)   sqrt(1 - h^2)
#     0.10     0.691       0.309        0.600
#     0.25     0.928       0.707        0.866
#     0.50     1.080       1.000        1.000
#
# Fifty-five per cent low at t = 0.10. The bands read it as "the pig is very
# narrow here", so their front-back coordinate collapsed toward zero near the
# crown and the belly and every ring bowed inward -- reported, exactly, as
# looking SWIRLY instead of like clean rings.
#
# `sqrt(1 - h^2)` -- a true ellipse rather than a sine -- is much closer and
# is still 13% low at the ends, because the body is a quad-sphere with a
# flattened belly and a bored rump rather than an ellipsoid. So this is the
# measurement, and this file's own header argument applies: a MEASUREMENT
# AGAINST A MODEL OF A THING IS NOT A MEASUREMENT OF THE THING.
#
# `build_pig.py` prints this table on every build, under "PASTE INTO
# pig_uv.BODY_RADIUS". Rebuild the pig and it hands you the new one.
BODY_RADIUS_PEAK = 1.0800
BODY_RADIUS = (
    0.3072, 0.5341, 0.6563, 0.7393, 0.8118, 0.8638, 0.9354,
    0.9642, 0.9843, 0.9961, 1.0000, 0.9961, 0.9861, 0.9642,
    0.9354, 0.8638, 0.8118, 0.7393, 0.6563, 0.5341, 0.3072,
)


def body_radius(t):
    """Horizontal radius at body fraction t (0 at the belly, 1 at the crown).

    LINEARLY INTERPOLATED BETWEEN MEASURED SAMPLES, which is enough at 21 of
    them: the widest gap between neighbours is 0.23 of the peak radius at the
    very bottom, where the profile is steepest, and under 0.02 anywhere a
    pattern is actually read.

    Returned in the same units as the body's own half-width, so a caller
    comparing against a front-back coordinate in body units needs no scaling.
    """
    if t <= 0.0:
        return BODY_RADIUS[0] * BODY_RADIUS_PEAK
    if t >= 1.0:
        return BODY_RADIUS[-1] * BODY_RADIUS_PEAK
    x = t * (len(BODY_RADIUS) - 1)
    i = int(x)
    f = x - i
    lo = BODY_RADIUS[i]
    hi = BODY_RADIUS[min(i + 1, len(BODY_RADIUS) - 1)]
    return (lo + (hi - lo) * f) * BODY_RADIUS_PEAK
