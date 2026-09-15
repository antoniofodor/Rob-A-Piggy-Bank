# -*- coding: utf-8 -*-
"""Where everything lives. The one place that knows the folder layout.

    pig/        the ANIMAL -- its scenes and the meshes that get uploaded
    skins/      one folder per skin: its blend and its two sheets
    renders/    pictures, all reproducible, none of them kept
    *.py        the tools

WHY THIS IS A FILE. Before it, twenty scripts each built their own paths out of
`os.path.join(D, "pig.blend")` and friends -- so the layout was asserted in
about sixty places and moving one file meant finding all of them. That is the
shape this project has paid for repeatedly: the road width that drifted between
two files, the ride-key grammar that broke within the hour of being copied,
`SUNK` read by two halves of one shop. `pig_uv.py` exists for exactly this
reason one level down, and `skin_colours.py` for the same reason again.

The test is whether the next reorganisation is a diff in ONE file. It is.

A SKIN OWNS A FOLDER AND EVERYTHING IN IT IS NAMED AFTER THE SKIN.

    skins/tiger/tiger.blend             what you open and turn dials in
    skins/tiger/tiger_body_color.png    the two sheets that get uploaded
    skins/tiger/tiger_trim_color.png

which is why `skin_blend` takes a KEY rather than a filename: the folder, the
scene and both maps are all derivable from it, so there is no way to put a
tiger's blend in the bee's folder. `bake_skin.py` therefore needs `--skin` and
nothing else, where it used to need `--blend` as well and would cheerfully bake
one skin's materials into another skin's sheets if the two disagreed.

`find` IS THE COMPATIBILITY HALF, and it exists because a person typing a
command should not have to know this file. Anything named on a command line is
looked for as given, then in `pig/`, then in each skin folder -- so
`--blend pig_parts.blend` and `--blend pig/pig_parts.blend` and
`--blend tiger.blend` all resolve, and a name that matches nothing raises HERE,
naming what was searched, rather than failing inside Blender as a file-open
error twenty lines later.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# THE ANIMAL. Scene files and the .obj exports that are actually uploaded.
# Those two kinds sit together on purpose: an export is a fact about a
# particular scene, and separating them is how a stale .obj ends up beside a
# rebuilt .blend with nothing to say they disagree.
PIG = os.path.join(HERE, "pig")

# THE SKINS. One folder each; see the header.
SKINS = os.path.join(HERE, "skins")

# PICTURES. Everything in here is one command away from being remade, which is
# why `.gitignore` refuses the whole folder.
RENDERS = os.path.join(HERE, "renders")

for _d in (PIG, SKINS, RENDERS):
    os.makedirs(_d, exist_ok=True)

# The master scene every skin is built from, and the raw generator output it
# comes from. Named here rather than spelled in each caller.
PARTS = os.path.join(PIG, "pig_parts.blend")
RAW = os.path.join(PIG, "pig.blend")


def pig(name):
    """A file in `pig/` -- a scene or a mesh export."""
    return os.path.join(PIG, name)


def skin_dir(key):
    """A skin's folder, made if it is not there yet.

    `animal/` and `metal/` are in here too and are not skins in the sense the
    rest of this file means: they hold SHARED sheets named by marking type,
    which one Config row dresses several animals with. They share the folder
    because they share the upload story, and `skins/README.md` draws the line.
    """
    d = os.path.join(SKINS, key)
    os.makedirs(d, exist_ok=True)
    return d


def skin_blend(key):
    """`skins/<key>/<key>.blend` -- where a skin's scene lives, always."""
    return os.path.join(skin_dir(key), key + ".blend")


def skin_map(key, group):
    """`skins/<key>/<key>_<group>_color.png`, for group `body` or `trim`.

    The engine wants two sheets because the game ships a `Body` MeshPart and a
    joined `Trim` MeshPart with separate colours, so this is the game's own
    split rather than a filing choice.
    """
    return os.path.join(skin_dir(key), "%s_%s_color.png" % (key, group))


def skin_view(key):
    """`skins/<key>/<key>_view.blend` -- the game-lit preview scene.

    NAMED AFTER THE SKIN, WHICH IS WHAT MAKES TWO SKINS SAFE TO WORK ON AT
    ONCE. It was one shared `pig_view.blend`, and a shared name written by a
    PER-SKIN script is a collision waiting for the second person: two previews
    running together would each open the other's half-written scene, and the
    symptom is a picture of the wrong animal rather than an error.
    """
    return os.path.join(skin_dir(key), key + "_view.blend")


def render(name):
    """A picture. The folder is made on demand so no script has to."""
    os.makedirs(RENDERS, exist_ok=True)
    return os.path.join(RENDERS, name)


def find(name, kind="file"):
    """Resolve something named on a command line, wherever it actually lives.

    RAISES RATHER THAN RETURNING A PATH THAT IS NOT THERE. A missing blend
    handed to `bpy.ops.wm.open_mainfile` does not stop the script -- it leaves
    the CURRENT scene loaded and carries on, so a typo bakes the wrong pig
    instead of failing. That is the silent-failure shape this project refuses
    everywhere else, and it is worth two lines here.
    """
    if os.path.isabs(name) and os.path.exists(name):
        return name
    tried = []
    for base in [os.getcwd(), HERE, PIG] + [
            os.path.join(SKINS, d) for d in sorted(os.listdir(SKINS))
            if os.path.isdir(os.path.join(SKINS, d))]:
        p = os.path.join(base, name)
        tried.append(p)
        if os.path.exists(p):
            return p
    raise RuntimeError("no %s called %r. Looked in:\n  %s"
                       % (kind, name, "\n  ".join(tried)))
