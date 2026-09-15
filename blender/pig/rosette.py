# -*- coding: utf-8 -*-
"""The spotted cat. One coat graph, driven by numbers, worn by more than one skin.

WHY THIS IS A FILE, AND IT IS THE SIXTH TIME THIS PROJECT HAS MADE THE SAME
CALL. The leopard's graph is about three hundred and fifty lines, and the snow
leopard wants every one of them: the same Voronoi cell field, the same
tangent-plane distance, the same collapse of a ring into a solid spot, the same
width cap, the same freckles. Two copies of that is the near-identical
duplicate `CLAUDE.md` records over and over -- `RideSound` keeping a second copy
of the ride-key grammar and breaking within the hour, `SUNK` read by two halves
of one shop, the road width that drifted between two files. The rule it settles
on each time is the same: WHEN A NEW THING HAS TO BEHAVE LIKE AN EXISTING THING
IN FOURTEEN PLACES, MAKE IT ONE.

WHAT THIS IS NOT. It is not a general skin builder and it must not become one.
The tiger is a WAVE -- rings about the nose-tail axis, one phase expression --
and nothing in here would help it; the bee is two bands. This is the family of
animals whose markings are LOCAL OBJECTS scattered over a surface, and the test
for whether a new skin belongs here is whether its markings have a centre.

`WORKFLOW.md` SAYS TO COPY A SKIN SCRIPT AND CHANGE THE MIDDLE, AND THAT IS
STILL RIGHT FOR THE FIRST OF A KIND. The leopard was written that way, from the
tiger. What changed is that there is now a SECOND animal wanting the identical
middle, which is the moment the middle stops being part of the skin. A skin
file above this one is still what the workflow describes -- one dict of
tunables at the top, every number commented -- and it is now only that.

THE VERIFICATION THAT MATTERS IS THE ONE `WORKFLOW.md` NAMES: bake it and diff
the maps. This extraction claims to reproduce the leopard exactly, and that
claim was checked with `md5sum skins/leopard/*.png` before and after rather
than by reading the diff -- for the reason recorded there, that the bee's node
dumps were identical while its trim map differed by 23,174 texels.

---

THE SHAPE OF A ROSETTE, WHICH IS THE ONE THING WORTH UNDERSTANDING BEFORE
TURNING ANY DIAL.

Each Voronoi cell owns one marking. `d` is the distance from the shading point
to that cell's own centre, measured IN THE SURFACE'S TANGENT PLANE and expressed
in CELL units -- so a cell is about 1 across and its neighbour's centre about
0.5 away, whatever `scale` is set to. Every radius below reads against that, and
`scale` therefore moves the COUNT without moving how big a marking looks
relative to its neighbours.

    ink  =  |d - r| < w          a ring of radius r, w thick
    fill =   d < r + w*fill_over  its centre

Three things fall out of writing it that way and all three are load-bearing:

  * `r = 0` turns the ring into a DISC, because `|d - 0| < w` is `d < w`. So a
    solid spot is the same marking with its hole shut rather than a second
    pattern, and the two can never disagree about where a spot is. `solidity`
    is what drives `r` to zero.
  * `w` going NEGATIVE ends the ring, and because the test is a distance from a
    centre the two ends taper rather than being cut square. That is the only
    thing in here that makes petals.
  * `w` growing past `r` swallows the hole and draws a blob. That is what
    `max_w` refuses, and it refuses it geometrically rather than by tuning.
"""

from skin_colours import to_linear


def mix_rgb(nt, label=""):
    """A colour mix, whichever node this Blender calls it.

    `ShaderNodeMixRGB` is legacy and `ShaderNodeMix` carries three sets of
    A/B sockets for float, vector and colour on ONE node -- so a lookup by the
    name 'A' is ambiguous and an index is a magic number that moves between
    versions. Asking for the legacy node first and falling back keeps every
    call site reading as fac/a/b, and fails loudly here rather than wiring the
    wrong socket somewhere in the middle of the graph.
    """
    try:
        n = nt.nodes.new("ShaderNodeMixRGB")
        n.label = label
        return n, n.inputs[0], n.inputs[1], n.inputs[2], n.outputs[0]
    except RuntimeError:
        n = nt.nodes.new("ShaderNodeMix")
        n.data_type = 'RGBA'
        n.label = label
        return n, n.inputs[0], n.inputs[6], n.inputs[7], n.outputs[2]


# NOTHING ON EITHER OF THESE CATS FADES INTO ANYTHING ELSE.
#
# The theme is CARTOON, so every texel is one of the colours the caller named
# and never a blend of two. That is enforced at the graph's output rather than
# asked of each mask: every factor reaching a colour mix goes through `hard`,
# so a soft mask anywhere upstream moves an EDGE rather than smearing one.
#
# It is not a preference about these two, it is the rule for all of them --
# `WORKFLOW.md`, "Nothing fades". Softness that survives is softness on a
# WIDTH, which tapers a stroke to a point in full ink and is a different thing.
NO_FADING = True


def coat(bpy, name, S):
    """One spotted coat as a material, built from the spec dict `S`.

    BUILT ONCE PER MATERIAL AND DELIBERATELY NOT SHARED between the body and
    the trim. `bake_skin.py` walks each object's material slots and points
    every material at the group's bake image, so a material worn by both groups
    would have its image node repointed by the second bake and the first sheet
    would come back blank. Two datablocks with one graph is the cheap way to
    keep those two bakes independent; the graph is generated, so they cannot
    drift.

    `S` carries the colours and five tunable dicts. Every key is required
    except `dorsal`, which is the one thing an animal may not have -- see
    below.
    """
    SPOTS = S['spots']
    FRECKLES = S['freckles']
    BELLY = S['belly']
    HEAD = S['head']
    LEGS = S['legs']
    NOSE = S['nose']

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    link = nt.links.new

    def node(kind, x, y, label=""):
        n = nt.nodes.new(kind)
        n.location = (x, y)
        n.label = label
        return n

    def math(op, x, y, label="", a=None, b=None, c=None):
        n = node("ShaderNodeMath", x, y, label)
        n.operation = op
        for i, v in ((0, a), (1, b), (2, c)):
            if v is not None:
                n.inputs[i].default_value = v
        return n

    def rng(x, y, label, lo, hi, out_lo, out_hi,
            interp='SMOOTHSTEP', clamp=True):
        n = node("ShaderNodeMapRange", x, y, label)
        n.interpolation_type = interp
        n.clamp = clamp
        n.inputs['From Min'].default_value = lo
        n.inputs['From Max'].default_value = hi
        n.inputs['To Min'].default_value = out_lo
        n.inputs['To Max'].default_value = out_hi
        return n

    def snoise(x, y, label, scale, offset, detail=2.0, spread=0.15):
        """A noise CENTRED ON ZERO and stretched so that +-1 is an ordinary
        excursion rather than an extreme one.

        Blender's noise Factor is bunched hard around 0.5 -- most of its mass
        sits inside 0.35..0.65 -- so the obvious `(fac - 0.5) * amount` needs an
        `amount` of about six before anything reaches the ends, and by then the
        rare tail is enormous. Stretching a narrow window to -1..1 with the
        clamp OFF gives a value whose typical range is about +-1 and whose tails
        still run past it, which is what a dial like `vary` needs in order to
        mean 'this many petals break' rather than 'a number I turned until it
        looked right'.

        THIS IS WHY `vary` HERE IS NOT THE TIGER'S `vary`, and `WORKFLOW.md`
        has a correction on that file's side worth reading before moving one.
        The tiger writes `1 + (Fac - 0.5)*vary` against a `Fac` bounded to
        0..1, so it bottoms out at `1 - vary/2` and needs `vary` past 2 before
        a stroke ever ends. Stretched, the same expression crosses zero around
        1.0. Read the helper, not the other skin.

        SAMPLED AT AN OFFSET POSITION, because two noises at the same place
        with different scales are still correlated -- their large features line
        up -- so the size wobble and the petal breaks would happen in the same
        places and the coat would read as one repeating motif.
        """
        off = node("ShaderNodeVectorMath", x - 220, y, "offset")
        off.operation = 'ADD'
        off.inputs[1].default_value = offset
        n = node("ShaderNodeTexNoise", x, y, label)
        n.noise_dimensions = '3D'
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = 0.55
        link(off.outputs['Vector'], n.inputs['Vector'])
        s = rng(x + 200, y, "centre and stretch",
                0.5 - spread, 0.5 + spread, -1.0, 1.0,
                interp='LINEAR', clamp=False)
        link(n.outputs['Fac'], s.inputs['Value'])
        return off, s

    # ---- where am I on the pig ---------------------------------------
    co = node("ShaderNodeTexCoord", -2600, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -2400, 0, "x across / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']

    # ---- the pale underside ------------------------------------------
    lift = math('MULTIPLY_ADD', -2200, 900, "z + tilt*y", b=BELLY['tilt'])
    link(Y, lift.inputs[0])
    link(Z, lift.inputs[2])
    belly_a = rng(-2000, 900, "pale below", BELLY['lo'], BELLY['hi'], 1.0, 0.0)
    link(lift.outputs[0], belly_a.inputs['Value'])
    leg_out = rng(-2000, 700, "but not the legs",
                  BELLY['leg_lo'], BELLY['leg_hi'], 0.0, 1.0)
    link(Z, leg_out.inputs['Value'])
    belly = math('MULTIPLY', -1780, 820, "PALE MASK")
    link(belly_a.outputs['Result'], belly.inputs[0])
    link(leg_out.outputs['Result'], belly.inputs[1])

    # ---- the rosette field -------------------------------------------
    vor = node("ShaderNodeTexVoronoi", -2200, -200, "one cell per rosette")
    if hasattr(vor, "voronoi_dimensions"):
        vor.voronoi_dimensions = '3D'
    vor.feature = 'F1'
    vor.distance = 'EUCLIDEAN'
    vor.inputs['Scale'].default_value = SPOTS['scale']
    vor.inputs['Randomness'].default_value = SPOTS['randomness']
    link(co.outputs['Object'], vor.inputs['Vector'])

    # THE DISTANCE IS MEASURED IN THE SURFACE'S OWN TANGENT PLANE, NOT IN 3D,
    # AND THAT IS THE ANSWER TO "TOO SPARSE" RATHER THAN ANY OF THE DIALS.
    #
    # `Distance` is the straight-line distance to the cell centre, and the
    # centre is a point in a 3D LATTICE while the pig is a SHELL through it. So
    # a centre sitting a little way under the surface draws a ring of radius
    # `sqrt(r^2 - depth^2)` -- smaller than asked for -- and one sitting deeper
    # than `r` draws NOTHING AT ALL. Measured on the leopard's first four
    # builds, that is a fifth to a third of the coat simply absent, and it does
    # not show up as small spots that could be tuned bigger: a deep cell owns
    # its whole footprint on the surface, so what it leaves is a BLANK PATCH
    # the size of a rosette. Turning `scale` up makes more, smaller blanks.
    # Turning `r` up helps and costs the gaps between rosettes. Neither is the
    # fix.
    #
    # Projecting the offset onto the tangent plane throws the depth away, so
    # every cell draws a full-size rosette wherever its centre happens to sit.
    # `Voronoi -> Position` is in the SAME SPACE AS ITS INPUT -- measured
    # rather than assumed, by reconstructing `Distance` from it both ways and
    # rendering the error: input-space came back at 0.0003 and scaled-space at
    # 0.97. Guessing that would have been a rosette field subtly the wrong size
    # everywhere, which is exactly the class of thing nobody notices.
    #
    # WHAT IT COSTS is that a deep cell whose footprint is squeezed small draws
    # a FRAGMENT of a rosette clipped at the cell wall rather than a whole one.
    # That is the better failure: an arc still reads as a marking and a real
    # coat is full of them, where a blank reads as a bald patch.
    #
    # `Texture Coordinate -> Normal` rather than `Geometry -> Normal`, because
    # that one is already in OBJECT space -- the same frame the rest of this
    # graph works in. The two agree today only because every part sits at
    # identity, which is a fact about this scene rather than a rule.
    nrm = node("ShaderNodeVectorMath", -2000, -60, "unit surface normal")
    nrm.operation = 'NORMALIZE'
    link(co.outputs['Normal'], nrm.inputs[0])
    off = node("ShaderNodeVectorMath", -2000, 60, "sample -> cell centre")
    off.operation = 'SUBTRACT'
    link(vor.outputs['Position'], off.inputs[0])
    link(co.outputs['Object'], off.inputs[1])
    depth = node("ShaderNodeVectorMath", -1820, -60, "how far under the skin")
    depth.operation = 'DOT_PRODUCT'
    link(off.outputs['Vector'], depth.inputs[0])
    link(nrm.outputs['Vector'], depth.inputs[1])
    along = node("ShaderNodeVectorMath", -1640, -60, "the part to throw away")
    along.operation = 'SCALE'
    link(nrm.outputs['Vector'], along.inputs[0])
    link(depth.outputs['Value'], along.inputs['Scale'])
    tang = node("ShaderNodeVectorMath", -1460, 60, "the part along the skin")
    tang.operation = 'SUBTRACT'
    link(off.outputs['Vector'], tang.inputs[0])
    link(along.outputs['Vector'], tang.inputs[1])
    tlen = node("ShaderNodeVectorMath", -1280, 60, "how far, on the skin")
    tlen.operation = 'LENGTH'
    link(tang.outputs['Vector'], tlen.inputs[0])
    # BACK INTO CELL UNITS, because `Position` is in studs and `Distance` was
    # not -- and every radius in a skin file is written against a cell.
    dnode = math('MULTIPLY', -1100, 60, "in cell units", b=SPOTS['scale'])
    link(tlen.outputs['Value'], dnode.inputs[0])
    dist = dnode.outputs[0]
    # A RANDOM NUMBER ATTACHED TO THE CELL ITSELF. `Voronoi -> Color` is a
    # random colour per cell, so one channel of it is a per-rosette seed --
    # which is the only source of variation here that does not vary smoothly
    # across the surface, and therefore the only one that can make two touching
    # rosettes disagree.
    cellsep = node("ShaderNodeSeparateXYZ", -2000, -420, "per-cell random")
    link(vor.outputs['Color'], cellsep.inputs['Vector'])
    cell = cellsep.outputs['X']

    # ---- where a rosette closes into a solid spot --------------------
    head = rng(-2200, 480, "1 at the nose", HEAD['lo'], HEAD['hi'], 1.0, 0.0)
    link(Y, head.inputs['Value'])
    legs = rng(-2200, 300, "1 at the paw", LEGS['lo'], LEGS['hi'], 1.0, 0.0)
    link(Z, legs.inputs['Value'])
    under = math('MULTIPLY', -2000, 120, "the underside, mostly",
                 b=S['belly_solid'])
    link(belly.outputs[0], under.inputs[0])
    cell_solid = rng(-2000, -600, "some cells anyway",
                     SPOTS['solid_lo'], SPOTS['solid_hi'], 1.0, 0.0)
    link(cell, cell_solid.inputs['Value'])
    s1 = math('MAXIMUM', -1780, 400)
    link(head.outputs['Result'], s1.inputs[0])
    link(legs.outputs['Result'], s1.inputs[1])
    s2 = math('MAXIMUM', -1600, 300)
    link(s1.outputs[0], s2.inputs[0])
    link(under.outputs[0], s2.inputs[1])
    solidity = math('MAXIMUM', -1420, 200, "SOLIDITY")
    link(s2.outputs[0], solidity.inputs[0])
    link(cell_solid.outputs['Result'], solidity.inputs[1])
    keep_ring = math('SUBTRACT', -1240, 200, "1 where it stays a ring",
                     a=1.0)
    link(solidity.outputs[0], keep_ring.inputs[1])

    # ---- how big this rosette is -------------------------------------
    # EVERY RADIUS IN THIS GRAPH IS CLAMPED, and that is the rule rather than
    # three separate decisions. `snoise` runs to about +-3.3, so a radius
    # written as `r * (1 + vary*s)` reaches twice nominal in the tails -- and a
    # rosette twice nominal is past its own cell wall, where `F1` hands it to
    # the neighbour and two rosettes fuse into one shapeless patch. That is
    # what the leopard's first build's crown was full of.
    sz_off, sz = snoise(-2200, -900, "SIZE noise",
                        SPOTS['size_scale'], (0.0, 0.0, 0.0))
    link(co.outputs['Object'], sz_off.inputs[0])
    r_place = rng(-1700, -900, "radius, place to place", -1.0, 1.0,
                  SPOTS['r'] * (1.0 - SPOTS['size_vary']),
                  SPOTS['r'] * (1.0 + SPOTS['size_vary']), interp='LINEAR')
    link(sz.outputs['Result'], r_place.inputs['Value'])
    r_cell = rng(-1700, -1080, "and cell to cell", 0.0, 1.0,
                 1.0 - SPOTS['cell_vary'], 1.0 + SPOTS['cell_vary'],
                 interp='LINEAR')
    link(cell, r_cell.inputs['Value'])
    r1 = math('MULTIPLY', -1500, -960, "this rosette's radius")
    link(r_place.outputs['Result'], r1.inputs[0])
    link(r_cell.outputs['Result'], r1.inputs[1])

    # ---- and how far from round --------------------------------------
    wb_off, wb = snoise(-2200, -1300, "WOBBLE noise",
                        SPOTS['wobble_scale'], (11.0, 4.0, -7.0))
    link(co.outputs['Object'], wb_off.inputs[0])
    wb_s = rng(-1700, -1300, "1 +- wobble, clamped", -1.0, 1.0,
               1.0 - SPOTS['wobble'], 1.0 + SPOTS['wobble'], interp='LINEAR')
    link(wb.outputs['Result'], wb_s.inputs['Value'])
    r2 = math('MULTIPLY', -1500, -1200, "wobbled radius")
    link(r1.outputs[0], r2.inputs[0])
    link(wb_s.outputs['Result'], r2.inputs[1])
    # THE COLLAPSE. `abs(d - 0) < w` is `d < w`, a disc -- so a solid spot is
    # the same rosette with its hole shut rather than a second pattern, and the
    # two can never disagree about where a spot is.
    r_ring = math('MULTIPLY', -1300, -1200, "RADIUS (0 = a solid spot)")
    link(r2.outputs[0], r_ring.inputs[0])
    link(keep_ring.outputs[0], r_ring.inputs[1])

    # ---- how thick the petal is here ---------------------------------
    vr_off, vr = snoise(-2200, -1700, "PETAL noise",
                        SPOTS['vary_scale'], (-6.0, 13.0, 5.0))
    link(co.outputs['Object'], vr_off.inputs[0])
    # WHERE THIS GOES NEGATIVE THE RING IS CUT, and that is the whole trick.
    # A continuous annulus is a bullseye; cut in three or four places it is a
    # rosette. Nothing else in this graph makes petals.
    w_var = math('MULTIPLY_ADD', -1700, -1700, "1 +- vary, and past zero",
                 b=SPOTS['vary'], c=1.0)
    link(vr.outputs['Result'], w_var.inputs[0])
    w_base = math('MULTIPLY', -1500, -1700, "petal half-width",
                  b=SPOTS['w'])
    link(w_var.outputs[0], w_base.inputs[0])
    # A collapsed rosette draws a disc of radius `w`, which is smaller than a
    # real cat's face and leg spots -- so the solid regions get a gain.
    solid_w = rng(-1500, -1880, "solid spots a touch bigger", 0.0, 1.0,
                  1.0, SPOTS['solid_gain'], interp='LINEAR')
    link(solidity.outputs[0], solid_w.inputs['Value'])
    head_w = rng(-1500, -2060, "and the face's are smaller", 0.0, 1.0,
                 1.0, 1.0 - S['head_shrink'], interp='LINEAR')
    link(head.outputs['Result'], head_w.inputs['Value'])
    w1 = math('MULTIPLY', -1300, -1780, "")
    link(w_base.outputs[0], w1.inputs[0])
    link(solid_w.outputs['Result'], w1.inputs[1])
    w2 = math('MULTIPLY', -1120, -1780, "")
    link(w1.outputs[0], w2.inputs[0])
    link(head_w.outputs['Result'], w2.inputs[1])

    # THE CAP, AND IT IS TWO CASES BECAUSE A SOLID SPOT HAS NO RING TO KEEP
    # OPEN. On a rosette the ceiling is a fraction of THIS rosette's radius, so
    # `|d - r| < w` can never swallow its own hole however far the width noise
    # runs. On a solid spot `r` is zero by construction, so that ceiling would
    # be zero too and the spot would vanish -- which is what a `MAXIMUM` of the
    # two was written as first, and it is wrong: the solid floor is the LARGER
    # of the pair, so it won everywhere and the ring cap never bound at all.
    #
    # ADDING THEM ON `solidity` IS THE FIX AND IT IS NOT A TRICK. The two terms
    # are each other's complement by construction -- `r_ring` is already
    # multiplied by `1 - solidity` -- so at either end exactly one of them is
    # live, and the band between hands a half-collapsed rosette a ceiling
    # between the two rather than a switch somebody has to place.
    cap_ring = math('MULTIPLY', -1120, -1980, "a fraction of the radius",
                    b=SPOTS['max_w'])
    link(r_ring.outputs[0], cap_ring.inputs[0])
    cap = math('MULTIPLY_ADD', -940, -1900, "CEILING",
               b=SPOTS['w'] * SPOTS['solid_gain'])
    link(solidity.outputs[0], cap.inputs[0])
    link(cap_ring.outputs[0], cap.inputs[2])
    width = math('MINIMUM', -760, -1780, "WIDTH HERE")
    link(w2.outputs[0], width.inputs[0])
    link(cap.outputs[0], width.inputs[1])

    # ---- ink, and the fill under it ----------------------------------
    ring_d = math('SUBTRACT', -1280, -1080, "")
    link(dist, ring_d.inputs[0])
    link(r_ring.outputs[0], ring_d.inputs[1])
    ring = math('ABSOLUTE', -1100, -1200, "distance from the ring")
    link(ring_d.outputs[0], ring.inputs[0])
    ink_raw = math('LESS_THAN', -900, -1200, "inside a petal?")
    link(ring.outputs[0], ink_raw.inputs[0])
    link(width.outputs[0], ink_raw.inputs[1])

    # THE FILL REACHES UNDER THE PETALS rather than up to them, so no coat
    # colour shows between the centre and the ring around it -- and because it
    # is measured against the SAME wobbling radius and the SAME varying width,
    # the centre is irregular in exactly the places the petals are.
    fill_r = math('MULTIPLY_ADD', -900, -1000, "the centre's own radius",
                  b=SPOTS['fill_over'])
    link(width.outputs[0], fill_r.inputs[0])
    link(r_ring.outputs[0], fill_r.inputs[2])
    fill_raw = math('LESS_THAN', -720, -1000, "inside the centre?")
    link(dist, fill_raw.inputs[0])
    link(fill_r.outputs[0], fill_raw.inputs[1])
    fill_ring = math('MULTIPLY', -540, -1000, "no centre in a solid spot")
    link(fill_raw.outputs[0], fill_ring.inputs[0])
    link(keep_ring.outputs[0], fill_ring.inputs[1])

    # ---- only the nose pad is cleared --------------------------------
    # THE EYES ARE DELIBERATELY NOT CLEARED, which reverses the tiger's rule
    # and `WORKFLOW.md`'s item 6 for this whole family. Both say to keep
    # markings off the eyes, and the reason they give is exact: the eyes are
    # code-built parts standing proud of the body at (+-0.318, -0.889, 0.364),
    # so a marking running up to their rim reads as a SMEAR. That is a fact
    # about a STRIPE -- a long stroke arriving at a black dome has nowhere to
    # end, so it ends on the dome and the two merge.
    #
    # A SPOT DOES NOT SMEAR, BECAUSE IT ALREADY HAS AN END. A spotted cat's
    # face is freckled right up to the eye. What the clearance actually drew
    # was a bare HALO round each eye -- a soft disc of nothing on the one part
    # of the animal anybody looks at -- because it was a smoothstepped fade
    # rather than a hard edge, so it did not read as "no spot here", it read as
    # the pattern being rubbed out.
    #
    # The nose pad keeps its clearance, and the difference is worth stating:
    # that one is not a hole in the pattern, it is a different COLOUR with its
    # own boundary, so there is nothing for a spot to fade into.
    nose_pad = rng(-2200, 1100, "the snout disc",
                   NOSE['lo'], NOSE['hi'], 1.0, 0.0)
    link(Y, nose_pad.inputs['Value'])
    keep = math('SUBTRACT', -1480, 1100, "no spots on the pad", a=1.0)
    link(nose_pad.outputs['Result'], keep.inputs[1])

    # ---- the freckles ------------------------------------------------
    # A SECOND, FINER FIELD FOR THE FACE AND THE LEGS, AND IT IS THE ONE PLACE
    # THIS GRAPH ADMITS A SECOND PATTERN. Everything else is one Voronoi with a
    # mask on it, deliberately -- see `solidity`. Freckles cannot be: a cat's
    # cheek carries a dozen small dots across the width of one flank rosette,
    # and ONE cell field cannot be dense on the head and coarse on the flank at
    # the same time, because `scale` is global. Shrinking the flank field's
    # spots on the head was tried first and is what the render showed: the
    # front third of the animal went BLANK, because there are only one or two
    # cells across a cheek and making their dots smaller removed the last of
    # them.
    #
    # It is solid dots and nothing else -- no ring, no centre, no wobble --
    # which is both what a cat's face actually has and what keeps this cheap.
    # MASKED TO `s1`, which is head-or-leg and is already computed for
    # `solidity`, so the freckles and the solid spots cannot disagree about
    # where the head is.
    fvor = node("ShaderNodeTexVoronoi", -2200, -2400, "one cell per freckle")
    if hasattr(fvor, "voronoi_dimensions"):
        fvor.voronoi_dimensions = '3D'
    fvor.feature = 'F1'
    fvor.distance = 'EUCLIDEAN'
    fvor.inputs['Scale'].default_value = SPOTS['scale'] * FRECKLES['scale_mul']
    fvor.inputs['Randomness'].default_value = 1.0
    link(co.outputs['Object'], fvor.inputs['Vector'])
    fcellsep = node("ShaderNodeSeparateXYZ", -2000, -2600, "per-cell random")
    link(fvor.outputs['Color'], fcellsep.inputs['Vector'])
    # A RADIUS OF ZERO IS HOW A CELL DECLINES TO HAVE A FRECKLE, rather than a
    # second mask multiplied in afterwards: `d < 0` is false everywhere, so the
    # dot is simply absent and there is no faint ghost of one to explain.
    f_r = rng(-1800, -2500, "not every cell", FRECKLES['lo'], FRECKLES['hi'],
              FRECKLES['r'], 0.0)
    link(fcellsep.outputs['X'], f_r.inputs['Value'])
    f_raw = math('LESS_THAN', -1600, -2400, "inside a freckle?")
    link(fvor.outputs['Distance'], f_raw.inputs[0])
    link(f_r.outputs['Result'], f_raw.inputs[1])
    freck = math('MULTIPLY', -1420, -2400, "head and legs only")
    link(f_raw.outputs[0], freck.inputs[0])
    link(s1.outputs[0], freck.inputs[1])

    # MAXIMUM RATHER THAN ADD, because both fields write the same ink and two
    # of them overlapping must not be twice as dark. Adding also breaks the
    # `Mix` factor's 0..1 contract in a way that does not error and shows up as
    # an over-saturated crust wherever the two happen to coincide.
    ink_all = math('MAXIMUM', -540, -1200, "either field")
    link(ink_raw.outputs[0], ink_all.inputs[0])
    link(freck.outputs[0], ink_all.inputs[1])

    ink = math('MULTIPLY', -360, -1200, "INK MASK")
    link(ink_all.outputs[0], ink.inputs[0])
    link(keep.outputs[0], ink.inputs[1])
    fill = math('MULTIPLY', -360, -1000, "FILL MASK")
    link(fill_ring.outputs[0], fill.inputs[0])
    link(keep.outputs[0], fill.inputs[1])

    # ---- the colours -------------------------------------------------
    # THE BASE TONE FIRST, THEN THE MARKINGS ON TOP, WHICH IS THE ORDER THAT
    # LETS A COAT HAVE MORE THAN ONE GROUND COLOUR. A marking is a mix driven
    # by a 0/1 mask, so anything mixed BEFORE it shows through wherever the
    # mask is 0 and is covered wherever it is 1 -- with nothing to keep in
    # step.
    x = -400

    # ---- NOTHING FADES ------------------------------------------------
    # EVERY FACTOR THAT REACHES A COLOUR PASSES THROUGH HERE, AND THAT IS A
    # STRUCTURAL RULE RATHER THAN A TIDY-UP. A `Mix` factor of 0.4 does not
    # draw less of something -- it draws a colour that was never authored,
    # 40% of the way between two that were. On a cartoon coat that reads as an
    # airbrush: a nose pad that dissolves into the cheek, a belly line that
    # smears, a marking at half strength. See `NO_FADING` and `WORKFLOW.md`.
    #
    # Softness on a WIDTH is the opposite and is kept everywhere it appears --
    # that is a stroke tapering to a point, which is drawn in full ink the
    # whole way. A mask on the ink can only cut; a mask on the width can taper.
    def hard(sock, x, y, what):
        n = math('GREATER_THAN', x, y, "%s: one colour or the other" % what,
                 b=0.5)
        link(sock, n.inputs[0])
        return n.outputs[0]

    # THE DORSAL SHADE IS OPTIONAL AND IS BUILT ONLY WHEN IT IS ASKED FOR.
    # A leopard is one tawny; a snow leopard is smoke over the back grading to
    # near-white at the flank, and without that a pale animal has no form at
    # all -- the markings float on a flat sheet. Building it unconditionally
    # with a zero factor would be a node that does nothing on half the skins
    # here AND would have changed the leopard's graph, which this extraction
    # promised not to do. `None` means no node.
    if S.get('dorsal'):
        DORSAL = S['dorsal']
        d_lift = math('MULTIPLY_ADD', -800, 1300, "z + tilt*y",
                      b=DORSAL['tilt'])
        link(Y, d_lift.inputs[0])
        link(Z, d_lift.inputs[2])
        d_mask = rng(-620, 1300, "smoke along the back",
                     DORSAL['lo'], DORSAL['hi'], 0.0, 1.0)
        link(d_lift.outputs[0], d_mask.inputs['Value'])
        md, fd, ad, bd, od = mix_rgb(nt, "coat -> smoke over the back")
        md.location = (x, 1100)
        ad.default_value = to_linear(S['coat']) + (1.0,)
        bd.default_value = to_linear(DORSAL['colour']) + (1.0,)
        link(hard(d_mask.outputs['Result'], x - 400, 1300,
                  "the dorsal shade"), fd)
        base = od
        x += 200
    else:
        base = None

    m1, f1, a1, b1, o1 = mix_rgb(nt, "coat -> pale underside")
    m1.location = (x, 900)
    if base is None:
        a1.default_value = to_linear(S['coat']) + (1.0,)
    else:
        link(base, a1)
    b1.default_value = to_linear(S['pale']) + (1.0,)
    link(hard(belly.outputs[0], x - 400, 900, "the pale underside"),
         f1)

    m2, f2, a2, b2, o2 = mix_rgb(nt, "the snout pad")
    m2.location = (x + 200, 900)
    b2.default_value = to_linear(S['snout']) + (1.0,)
    link(hard(nose_pad.outputs['Result'], x - 400, 1100,
              "the snout pad"), f2)
    link(o1, a2)

    m3, f3, a3, b3, o3 = mix_rgb(nt, "the rosette centre")
    m3.location = (x + 400, 700)
    b3.default_value = to_linear(S['fill']) + (1.0,)
    link(hard(fill.outputs[0], x + 200, 700, "the rosette centre"),
         f3)
    link(o2, a3)

    m4, f4, a4, b4, o4 = mix_rgb(nt, "lay the petals on")
    m4.location = (x + 600, 500)
    b4.default_value = to_linear(S['ink']) + (1.0,)
    link(hard(ink.outputs[0], x + 400, 500, "the petals"), f4)
    link(o3, a4)

    bsdf = node("ShaderNodeBsdfPrincipled", x + 820, 400)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o4, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", x + 1140, 400)
    link(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat


def flat(bpy, name, rgb):
    """A single-colour material -- the inner ear, which is the one part of any
    of these animals that shows skin rather than fur."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs['Base Color'].default_value = to_linear(rgb) + (1.0,)
    b.inputs['Roughness'].default_value = 0.88
    return mat


def build(bpy, paths, skin, spec, src, out):
    """Open the master, seat this skin's materials on it, save the copy.

    THE FIVE PARTS AND THE EAR'S TWO SLOTS ARE THE SAME ON EVERY ANIMAL HERE,
    which is why the driver is shared as well as the graph. The ear keeps its
    slots and the ORDER they are in: face assignment lives on the polygons as a
    `material_index`, so replacing slot 0 with slot 0 and slot 1 with slot 1
    inherits the selection somebody made by hand -- clear the list and append
    in the wrong order and the inner ear paints the outside with nothing to say
    so. Seated through `skin_parts.assign`, which is the one place that knows
    `materials.clear()` also resets every polygon's slot index.
    """
    import os
    from skin_parts import assign, face_slots

    bpy.ops.wm.open_mainfile(filepath=paths.find(src, "blend"))

    body_mat = coat(bpy, skin + "_body", spec)
    trim_mat = coat(bpy, skin + "_trim", spec)
    ear_mat = flat(bpy, skin + "_ear_inner", spec['ear'])

    pairs = [("Body", [body_mat]),
             ("Snout", [trim_mat]),
             ("Legs", [trim_mat]),
             ("Tail", [trim_mat]),
             ("Ears", [trim_mat, ear_mat])]
    assign(bpy, pairs, "%s  (from %s)" % (skin.upper(), src))

    for n, c in face_slots(bpy, [n for n, _ in pairs]):
        if len(c) > 1:
            print("  %-6s faces per slot %s  <- hand selection, intact"
                  % (n, c))

    bpy.ops.wm.save_as_mainfile(filepath=out)
    S = spec['spots']
    print("")
    print("  saved %s -- %s is untouched"
          % (os.path.basename(out), os.path.basename(src)))
    print("  about %d cells across the body, outer radius %.2f of a cell"
          % (round(S['scale'] * 2.0), S['r'] + S['max_w'] * S['r']))
