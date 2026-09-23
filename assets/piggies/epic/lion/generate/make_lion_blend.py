# -*- coding: utf-8 -*-
"""Build the Lion's coat as a node graph, in its own blend file.

    blender.exe --background --python assets/piggies/epic/lion/generate/make_lion_blend.py

Writes `assets/piggies/epic/lion/source/lion.blend`. Then the ordinary loop:

    blender.exe --background --python make/bake_skin.py       -- --skin lion
    blender.exe --background --python make/make_view_blend.py -- --skin lion --render
    blender.exe --background --python look/preview_fur.py     -- --skin lion

THE PATTERN IS DEFINED IN 3D, NEVER IN UV SPACE -- see `WORKFLOW.md`. The
shader is evaluated at a POSITION on the surface, so Smart UV Project can
rotate every island however it likes and the mane still lands where the
geometry says it lands. The bake resolves it afterwards.

A LION IS A RING, AND THAT IS A FOURTH PRIMITIVE. The tiger is a wave, the
leopard a cell field, the cow a level set; a lion has no repeating marking at
all. What says LION from the pavement is one region -- the mane -- sitting
where the head meets the body, with the face cut out of the front of it. So
this graph is three masks and no noise on any of them except a ragged
trailing edge:

    the MANE     a band of Y round the neck, from just behind the muzzle to
                 a wobbling line on the shoulders, that covers crown, cheeks
                 and chest together -- which is exactly where the fur mesh
                 (`Config.FUR_SETS.mane`: "a parted crest over the crown, a
                 sweep down each cheek and a brisket across the chest") will
                 stand. The fur takes the BODY sheet's own colour at its own
                 position (`PiggyModel.applyFur`), so painting the band here
                 is what colours the ruff as well as the hide under it.
    the FACE     a window cut out of the front of the band, so the eyes,
                 the brow and the cheeks read tawny inside a dark ring.
    the BELLY    the tiger's tilted plane, cream, keeping off the legs.

THE COORDINATE FRAME IS THE PIG'S OWN, measured off the mesh rather than
assumed. Every part sits at identity, so object space IS world space and all
five parts share one frame:

    x   across          body reaches +-1.000
    y   NOSE to TAIL    snout tip -1.381, body -1.080..1.052, tail tip 1.465
    z   floor to CROWN  legs -1.020, body -0.960..0.960, ear tip 1.309

So -Y is the face and +Z is up. The eyes stand at (+-0.318, -0.889, 0.364).
"""

# --- find the toolkit, wherever this script has been filed ------------------
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not (_os.path.exists(_os.path.join(_root, "paths.py"))
           or _os.path.exists(_os.path.join(_root, "blender", "pig", "paths.py"))):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find blender/pig/paths.py above %s" % __file__)
    _root = _up
if not _os.path.exists(_os.path.join(_root, "paths.py")):
    _root = _os.path.join(_root, "blender", "pig")
if _root not in _sys.path:
    _sys.path.insert(0, _root)
# ---------------------------------------------------------------------------
D = _root

import paths   # noqa: E402 -- the one place that knows the layout
import bpy, os, sys

from skin_colours import skin, to_linear   # noqa: E402
from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("lion"))

# --------------------------------------------------------------- the colours
# READ OFF `Config.SKINS.lion` rather than copied, for the reason
# `skin_colours.py` exists: a sheet judged in colours the game does not ship
# is a sheet judged wrong. `body` is the hide; `trim` is the darker tawny the
# game paints on the four trim parts, and here it is the EAR BACK.
TAWNY, EAR_BACK = skin("lion")

# THE MANE IS `Config.SKINS.lion.fur`, HARDCODED WITH A NOTE, for the reason
# the cow gives about its ink: `skin_colours.skin()` parses the body/trim pair
# and nothing else, and a second parser for one field is a worse drift than a
# literal that names where it came from. The fur mesh is painted this colour
# by `PiggyModel.applyFur` and then wears this SHEET over it, so the two have
# to agree or the ruff would read as a different animal from the ring it
# stands on.
#
# DEEPER THAN THE FUR COLOUR ON PURPOSE. At (166, 104, 38) the first bake's
# mane sat one shade off the tawny under the game's sun and read as a collar;
# a full-colour sheet ignores the part colour anyway (`AlphaMode.Overlay` at
# alpha 255 is the map), so the fur's `Color3` only ever decides the swatch
# and the primitives fallback. Keep `Config.SKINS.lion.fur` in the same family
# for those two readers; the sheet is what the animal wears.
MANE = (150 / 255., 80 / 255., 42 / 255.)       # the reference's rust; Config fur matches
PALE = (246 / 255., 222 / 255., 176 / 255.)     # the belly, the muzzle and the paws
INK = (58 / 255., 40 / 255., 30 / 255.)         # the nose and the tail tuft
EAR_INNER = (232 / 255., 190 / 255., 150 / 255.)

# --------------------------------------------------------------- the masks
# EVERY NUMBER THAT DECIDES WHAT THE COAT LOOKS LIKE, with what it does.
MANE_BAND = dict(
    y_lo=-1.10,      # the mane starts just behind the muzzle...
    y_hi=-0.12,      # ...and ends on the shoulders, at this Y...
    ragged=0.14,     # ...give or take this much of wobble along the edge
    scale=2.6,       # how coarse the wobble is (studs per lobe, roughly)
)
FACE = dict(
    y=-0.66,         # the window reaches this far back from the nose
    z_lo=-0.38,      # ...from the chin...
    z_hi=0.55,       # ...to the brow (the eyes are at z 0.364)
    x=0.60,          # ...and this wide (the eyes are at |x| 0.318)
    soft=0.04,       # how sharp its edges are before `hard` cuts them
)
BELLY = dict(
    hi=-0.16, lo=-0.40,   # cream below this tilted plane
    tilt=0.30,            # the plane rises toward the tail
    leg_lo=-0.86, leg_hi=-0.62,   # but the legs stay tawny
)
MUZZLE = dict(y=-0.78, z=0.30, x=0.78, soft=0.04)   # a big cream muzzle under the eyes, like the reference
PAWS = dict(lo=-0.86, hi=-0.80)     # cream feet: everything below this on the legs
TAIL = dict(lo=1.18, hi=1.24)       # the tuft: everything past this Y on the tail

NO_FADING = True


def mix_rgb(nt, label=""):
    """A colour mix, whichever node this Blender calls it -- see the tiger."""
    try:
        n = nt.nodes.new("ShaderNodeMixRGB")
        n.label = label
        return n, n.inputs[0], n.inputs[1], n.inputs[2], n.outputs[0]
    except RuntimeError:
        n = nt.nodes.new("ShaderNodeMix")
        n.data_type = 'RGBA'
        n.label = label
        return n, n.inputs[0], n.inputs[6], n.inputs[7], n.outputs[2]


def coat(name):
    """The lion's coat as one material. Built twice -- once for the body and
    once for the trim -- and deliberately not shared between them, because
    `bake_skin.py` repoints a material's image node per group and a shared
    material would have its first sheet blanked by the second bake."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)

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

    def rng(x, y, label, lo, hi, out_lo, out_hi):
        n = node("ShaderNodeMapRange", x, y, label)
        n.interpolation_type = 'SMOOTHSTEP'
        n.clamp = True
        n.inputs['From Min'].default_value = lo
        n.inputs['From Max'].default_value = hi
        n.inputs['To Min'].default_value = out_lo
        n.inputs['To Max'].default_value = out_hi
        return n

    link = nt.links.new

    def hard(sock, x, y, what):
        """One colour or the other, never a blend -- `WORKFLOW.md`, Nothing
        fades. Every factor that reaches a Mix passes through here."""
        n = math('GREATER_THAN', x, y, "%s: one colour or the other" % what,
                 b=0.5)
        link(sock, n.inputs[0])
        return n.outputs[0]

    co = node("ShaderNodeTexCoord", -2100, 0, "the pig's own frame")
    sep = node("ShaderNodeSeparateXYZ", -1900, 0, "x across / y nose-tail / z up")
    link(co.outputs['Object'], sep.inputs['Vector'])
    X, Y, Z = sep.outputs['X'], sep.outputs['Y'], sep.outputs['Z']

    # ---- the belly: the tiger's tilted plane, cream, keeping off the legs
    lift = math('MULTIPLY_ADD', -1700, 500, "z + tilt*y", b=BELLY['tilt'])
    link(Y, lift.inputs[0])
    link(Z, lift.inputs[2])
    belly_a = rng(-1500, 500, "cream below", BELLY['lo'], BELLY['hi'], 1.0, 0.0)
    link(lift.outputs[0], belly_a.inputs['Value'])
    leg_out = rng(-1500, 300, "but not the legs",
                  BELLY['leg_lo'], BELLY['leg_hi'], 0.0, 1.0)
    link(Z, leg_out.inputs['Value'])
    belly = math('MULTIPLY', -1250, 400, "CREAM MASK")
    link(belly_a.outputs['Result'], belly.inputs[0])
    link(leg_out.outputs['Result'], belly.inputs[1])

    # ---- the muzzle: a big cream patch on the lower face, under the eyes
    # and between the cheeks, the reference's own shape
    ms = MUZZLE['soft']
    mz_y = rng(-1700, 100, "forward enough", MUZZLE['y'] - ms, MUZZLE['y'] + ms, 1.0, 0.0)
    link(Y, mz_y.inputs['Value'])
    mz_z = rng(-1700, -60, "under the eyes", MUZZLE['z'] - ms, MUZZLE['z'] + ms, 1.0, 0.0)
    link(Z, mz_z.inputs['Value'])
    mz_ax = math('ABSOLUTE', -1700, -200, "abs x")
    link(X, mz_ax.inputs[0])
    mz_x = rng(-1520, -200, "between the cheeks", MUZZLE['x'] - ms, MUZZLE['x'] + ms, 1.0, 0.0)
    link(mz_ax.outputs[0], mz_x.inputs['Value'])
    mz1 = math('MULTIPLY', -1500, 40, "muzzle: y and z")
    link(mz_y.outputs['Result'], mz1.inputs[0])
    link(mz_z.outputs['Result'], mz1.inputs[1])
    muzzle = math('MULTIPLY', -1320, 40, "THE MUZZLE")
    link(mz1.outputs[0], muzzle.inputs[0])
    link(mz_x.outputs['Result'], muzzle.inputs[1])
    # ---- the paws: cream below a height on the legs (the body never reaches it)
    paws = rng(-1500, -100, "the cream paws", PAWS['lo'], PAWS['hi'], 1.0, 0.0)
    link(Z, paws.inputs['Value'])

    # ---- the mane: a band of Y with a ragged trailing edge
    wob_off = node("ShaderNodeVectorMath", -1900, -300, "offset")
    wob_off.operation = 'ADD'
    wob_off.inputs[1].default_value = (3.0, -5.0, 7.0)
    link(co.outputs['Object'], wob_off.inputs[0])
    wob = node("ShaderNodeTexNoise", -1700, -300, "RAGGED EDGE noise")
    wob.noise_dimensions = '3D'
    wob.inputs['Scale'].default_value = MANE_BAND['scale']
    wob.inputs['Detail'].default_value = 2.0
    wob.inputs['Roughness'].default_value = 0.55
    link(wob_off.outputs['Vector'], wob.inputs['Vector'])
    wob_c = math('SUBTRACT', -1500, -300, "centre on zero", b=0.5)
    link(wob.outputs['Fac'], wob_c.inputs[0])
    wob_s = math('MULTIPLY', -1320, -300, "ragged amount", b=MANE_BAND['ragged'])
    link(wob_c.outputs[0], wob_s.inputs[0])
    y_rag = math('ADD', -1140, -220, "y, wobbled")
    link(Y, y_rag.inputs[0])
    link(wob_s.outputs[0], y_rag.inputs[1])
    # The band: 1 between y_lo and y_hi. Two smoothsteps multiplied, both
    # narrow, and the product goes through `hard` below, so the wobble moves
    # an EDGE rather than smearing one.
    band_front = rng(-960, -160, "behind the muzzle", MANE_BAND['y_lo'] - 0.03,
                     MANE_BAND['y_lo'] + 0.03, 0.0, 1.0)
    link(Y, band_front.inputs['Value'])
    band_back = rng(-960, -360, "before the shoulders", MANE_BAND['y_hi'] - 0.03,
                    MANE_BAND['y_hi'] + 0.03, 1.0, 0.0)
    link(y_rag.outputs[0], band_back.inputs['Value'])
    band = math('MULTIPLY', -780, -260, "THE MANE BAND")
    link(band_front.outputs['Result'], band.inputs[0])
    link(band_back.outputs['Result'], band.inputs[1])

    # ---- the face: a window cut out of the front of the band
    s = FACE['soft']
    face_y = rng(-960, -600, "forward of the ears", FACE['y'] - s, FACE['y'] + s, 1.0, 0.0)
    link(Y, face_y.inputs['Value'])
    face_zlo = rng(-960, -760, "above the chin", FACE['z_lo'] - s, FACE['z_lo'] + s, 0.0, 1.0)
    link(Z, face_zlo.inputs['Value'])
    face_zhi = rng(-960, -920, "below the brow", FACE['z_hi'] - s, FACE['z_hi'] + s, 1.0, 0.0)
    link(Z, face_zhi.inputs['Value'])
    ax = math('ABSOLUTE', -1140, -1080, "|x|")
    link(X, ax.inputs[0])
    face_x = rng(-960, -1080, "between the cheeks", FACE['x'] - s, FACE['x'] + s, 1.0, 0.0)
    link(ax.outputs[0], face_x.inputs['Value'])
    f1 = math('MULTIPLY', -780, -700, "face: y and z")
    link(face_y.outputs['Result'], f1.inputs[0])
    link(face_zlo.outputs['Result'], f1.inputs[1])
    f2 = math('MULTIPLY', -600, -800, "face: and z above")
    link(f1.outputs[0], f2.inputs[0])
    link(face_zhi.outputs['Result'], f2.inputs[1])
    face = math('MULTIPLY', -420, -900, "THE FACE WINDOW")
    link(f2.outputs[0], face.inputs[0])
    link(face_x.outputs['Result'], face.inputs[1])
    not_face = math('SUBTRACT', -240, -900, "1 - face", a=1.0)
    link(face.outputs[0], not_face.inputs[1])
    mane = math('MULTIPLY', -60, -300, "MANE, face cut out")
    link(band.outputs[0], mane.inputs[0])
    link(not_face.outputs[0], mane.inputs[1])

    # ---- the tail tuft: everything past TAIL on the tail part
    tuft = rng(-1500, -1300, "the tail tuft", TAIL['lo'], TAIL['hi'], 0.0, 1.0)
    link(Y, tuft.inputs['Value'])

    # ---- the colours, laid on in order: tawny, cream belly, pale muzzle,
    # the mane over all of it, the tuft last
    m1, f1s, a1, b1, o1 = mix_rgb(nt, "tawny -> cream belly")
    m1.location = (300, 460)
    a1.default_value = to_linear(TAWNY) + (1.0,)
    b1.default_value = to_linear(PALE) + (1.0,)
    link(hard(belly.outputs[0], 120, 460, "the cream belly"), f1s)

    m2, f2s, a2, b2, o2 = mix_rgb(nt, "-> pale muzzle")
    m2.location = (500, 460)
    b2.default_value = to_linear(PALE) + (1.0,)
    link(hard(muzzle.outputs[0], 300, 700, "the muzzle"), f2s)
    link(o1, a2)

    m2b, f2bs, a2b, b2b, o2b = mix_rgb(nt, "-> cream paws")
    m2b.location = (600, 560)
    b2b.default_value = to_linear(PALE) + (1.0,)
    link(hard(paws.outputs['Result'], 400, 800, "the paws"), f2bs)
    link(o2, a2b)

    m3, f3s, a3, b3, o3 = mix_rgb(nt, "lay the mane on")
    m3.location = (700, 280)
    b3.default_value = to_linear(MANE) + (1.0,)
    link(hard(mane.outputs[0], 500, 280, "the mane"), f3s)
    link(o2b, a3)

    m4, f4s, a4, b4, o4 = mix_rgb(nt, "and the tail tuft")
    m4.location = (900, 280)
    b4.default_value = to_linear(INK) + (1.0,)
    link(hard(tuft.outputs['Result'], 700, 100, "the tuft"), f4s)
    link(o3, a4)

    bsdf = node("ShaderNodeBsdfPrincipled", 1100, 280)
    bsdf.inputs['Roughness'].default_value = 0.88
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.08
    link(o4, bsdf.inputs['Base Color'])
    out = node("ShaderNodeOutputMaterial", 1400, 280)
    link(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat


def flat(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs['Base Color'].default_value = to_linear(rgb) + (1.0,)
    b.inputs['Roughness'].default_value = 0.88
    return mat


bpy.ops.wm.open_mainfile(filepath=paths.find(SRC, "blend"))

body_mat = coat("lion_body")
trim_mat = coat("lion_trim")
ear_mat = flat("lion_ear_inner", EAR_INNER)
# THE SNOUT IS CREAM, PART OF THE MUZZLE. The reference's whole lower face is
# one cream mass with a small dark nose; on a pig the snout disc IS that mass,
# and its two sculpted nostrils are the dark in it. Painted dark it read as a
# black plate over the face.
snout_mat = flat("lion_snout", PALE)

ASSIGN = [("Body", [body_mat]),
          ("Snout", [snout_mat]),
          ("Legs", [trim_mat]),
          ("Tail", [trim_mat]),
          ("Ears", [trim_mat, ear_mat])]
assign(bpy, ASSIGN, "LION  (from %s)" % SRC)
for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s -- %s is untouched"
      % (os.path.relpath(OUT, D), os.path.relpath(SRC, D)))
print("  mane from y %.2f to %.2f, face window %.2f wide"
      % (MANE_BAND['y_lo'], MANE_BAND['y_hi'], FACE['x'] * 2))
