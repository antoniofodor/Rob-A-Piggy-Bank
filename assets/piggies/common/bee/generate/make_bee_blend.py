# -*- coding: utf-8 -*-
"""Rebuild the Bumblebee's coat, in its own blend file.

    blender.exe --background --python make_bee_blend.py

Writes `pig_bee.blend`. Then the ordinary loop -- see `WORKFLOW.md`.

THIS IS A TRANSCRIPTION, NOT AN AUTHORING. Every other skin script in here is
where the pattern was DESIGNED; this one is not. The bee was built by hand in
`pig_parts.blend` -- three materials, dragged out in the node editor -- and
this file is that graph read back off the mesh and written down, to the float.
It is here because of what `.gitignore` says two folders up: `*.blend` is
ignored, on the correct argument that a scene file is large and is rebuilt by
the script that made it. TRUE OF EVERYTHING IN THIS FOLDER EXCEPT THE BEE. It
had no script, so it was a large ignored binary holding work with no generator
behind it -- the same class of thing as the hand-painted masks, which
`.gitignore` goes out of its way to keep, and nobody had noticed the bee had
joined them.

VERIFIED BY BAKING IT, NOT BY READING IT. A transcription that is subtly wrong
is worse than none, because it looks like a backup. `pig_bee.blend` bakes to
sheets that are BYTE-IDENTICAL to `assets/piggies/common/bee/sheets/` as shipped -- same md5 on both
maps -- which is the only check that means anything here.

WHAT THE BEE ACTUALLY IS, since the graph is terse enough to be puzzling:

  * `Mapping.Vector` is plugged into `ColorRamp.Fac`. That is a VECTOR into a
    FLOAT socket, so Blender averages the components -- which turns the ramp's
    position axis into the diagonal (x+y+z)/3, and the Mapping's rotation is
    what swings that diagonal onto the axis the bands should run about. It is a
    one-node way to get an arbitrary band direction and it is entirely legal.
  * The ramp is CONSTANT, so every band edge is hard. Six stops give three
    yellow bands and three black ones over the first half of the range, and
    CONSTANT means the last stop simply runs to the end.
  * The trim is two flat colours: yellow on the snout and the outer ear, black
    on the legs, the tail and the ear rims. Both are still ramps because that
    is what they were built from -- Material.001's two stops sit at the SAME
    position, which under CONSTANT resolves to the second one everywhere.

So the bee is a special case of what the tiger does the general way: bands
about an axis, hard edges, flat colours. It is kept in its own idiom rather
than rewritten into the tiger's because the point of this file is to preserve
what was authored, and a tidier version of somebody's work is a different
version of it.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds either `paths.py` or the repo root
# that holds `blender/pig/paths.py`, and puts `blender/pig/` on the path. Depth
# independent on purpose: this generator lives in `assets/piggies/<key>/
# generate/`, three levels under the repo, and the toolkit in `blender/pig/`,
# two levels under it -- a hardcoded `..` is a thing that breaks silently the
# first time anything is refiled (it did, on 2026-09-22, which is why the walk
# accepts both).
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


from skin_parts import assign, face_slots   # noqa: E402


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--blend", paths.PARTS)
OUT = arg("--out", paths.skin_blend("bee"))

# LINEAR, AND NOT CONVERTED HERE. Every other script in this folder goes
# through `skin_colours.to_linear` because it starts from a `Color3` byte
# triple in `Config`. These are the values as they sit in the authored file --
# YELLOW is sRGB (236, 160, 12), which is `Config.SKINS.bee.body` exactly, and
# INK is about (25, 24, 23). Round-tripping them through a conversion would
# introduce a difference in the last bit for no reason, and the whole claim of
# this file is that it changes nothing.
# NOTHING ON THIS ANIMAL FADES INTO ANYTHING ELSE, and on the bee it is free:
# there is no mask and no mix anywhere in this file. Every material is one flat
# authored colour, so there is no factor that could be anything but 0 or 1.
# `WORKFLOW.md`, "Nothing fades", is the rule the patterned skins have to work
# for; this is what it looks like when a skin has nothing to enforce.
NO_FADING = True

YELLOW = (0.8387992978096008, 0.3515326976776123, 0.003676507854834199, 1.0)
INK = (0.010329823940992355, 0.008568127639591694, 0.00802319310605526, 1.0)

# THE BAND EDGES, IN RAMP POSITION. Hand-placed, so they are not evenly spaced
# and must not be "corrected" into a series -- the unevenness is the authoring.
BANDS = [(0.0, YELLOW),
         (0.10454576462507248, INK),
         (0.25045496225357056, YELLOW),
         (0.32522761821746826, INK),
         (0.40806859731674194, YELLOW),
         (0.4909095764160156, INK)]

# THE ROTATION THAT AIMS THE DIAGONAL. See the header: the ramp reads the mean
# of the mapped vector, so this is what decides which way the bands run.
BAND_ROT = (0.9599310755729675, 0.7853981852531433, 0.013962632976472378)


def ramp_material(name, stops, rot=(0.0, 0.0, 0.0)):
    """TexCoord.Generated -> Mapping -> ColorRamp.Fac -> Base Color.

    The vector-into-a-float-socket link is reproduced rather than replaced with
    an explicit Separate/Add/Divide, because the implicit conversion is what
    the authored file does and an explicit version is only equivalent until
    somebody edits one of the three nodes it became.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)

    co = nt.nodes.new("ShaderNodeTexCoord")
    co.location = (-800, 0)
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.location = (-600, 0)
    mp.vector_type = 'POINT'
    mp.inputs['Rotation'].default_value = rot
    cr = nt.nodes.new("ShaderNodeValToRGB")
    cr.location = (-380, 0)
    cr.color_ramp.color_mode = 'RGB'
    cr.color_ramp.interpolation = 'CONSTANT'

    # A NEW RAMP ARRIVES WITH TWO STOPS AND THE FIRST CANNOT BE REMOVED, so the
    # existing pair is reused and the rest appended. Building the list by
    # `new()` alone leaves a stray black stop at 0 that shows as a dark sliver
    # at one band edge -- small enough to read as a rendering artefact.
    els = cr.color_ramp.elements
    while len(els) > len(stops):
        els.remove(els[-1])
    while len(els) < len(stops):
        els.new(1.0)
    for e, (pos, col) in zip(els, stops):
        e.position = pos
        e.color = col

    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (-80, 0)
    bsdf.inputs['Roughness'].default_value = 0.5
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (240, 0)

    nt.links.new(co.outputs['Generated'], mp.inputs['Vector'])
    nt.links.new(mp.outputs['Vector'], cr.inputs['Fac'])
    nt.links.new(cr.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    return mat


bpy.ops.wm.open_mainfile(filepath=paths.find(SRC, "blend"))

body = ramp_material("bee_body", BANDS, BAND_ROT)
# BOTH STOPS AT POSITION 0, WHICH UNDER `CONSTANT` IS FLAT. Written the way it
# was authored rather than collapsed to a single stop: a one-stop ramp is not
# the same object and would not read back the same if anybody diffed this
# against the file it came from.
warm = ramp_material("bee_trim", [(0.0, (0.0, 0.0, 0.0, 1.0)), (0.0, YELLOW)])
dark = ramp_material("bee_dark", [(0.0, INK), (1.0, INK)])

# THE SLOTS AND THEIR ORDER ARE THE AUTHORING, and the ear's two are the whole
# of the hand work in this skin -- 313 of 3326 faces picked by eye for the rim.
# That selection lives on the POLYGONS as a `material_index`, so it survives
# here for free; what must not move is which slot is which.
ASSIGN = [("Body", [body]),
          ("Snout", [warm]),
          ("Legs", [dark]),
          ("Tail", [dark]),
          ("Ears", [warm, dark])]

# SEATED THROUGH `skin_parts.assign`, WHICH IS THE ONE PLACE THAT KNOWS THAT
# `materials.clear()` ALSO RESETS EVERY POLYGON'S SLOT INDEX. Both skin scripts
# carried their own copy of that loop and both destroyed the ear selection.
assign(bpy, ASSIGN, "BEE  (from %s)" % SRC)

for _n, _c in face_slots(bpy, [n for n, _ in ASSIGN]):
    if len(_c) > 1:
        print("  %-6s faces per slot %s  <- hand selection, intact"
              % (_n, _c))

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("")
print("  saved %s" % os.path.relpath(OUT, D))
print("  bake it and diff against assets/piggies/common/bee/sheets/ -- the maps must come back")
print("  byte-identical, or this is not a backup of anything")
