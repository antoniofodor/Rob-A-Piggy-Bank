# -*- coding: utf-8 -*-
"""Where everything lives. The one place that knows the folder layout.

    blender/pig/pig/          the ANIMAL -- its scenes and the meshes that get uploaded
    blender/pig/renders/      pictures, all reproducible, none of them kept
    blender/pig/*.py          the tools
    assets/piggies/<tier>/<key>/   ONE FOLDER PER PIGGY SKIN, sorted by tier -- the source
                              of truth (designer, 2026-09-22). See `assets/piggies/README.md`.
    assets/skins/animal/      only the TIER GALLERY pages now (index.html, manifest.json,
                              README.md per tier); every package moved under its piggy

WHY THIS IS A FILE. Before it, twenty scripts each built their own paths out of
`os.path.join(D, "pig.blend")` and friends -- so the layout was asserted in
about sixty places and moving one file meant finding all of them. That is the
shape this project has paid for repeatedly: the road width that drifted between
two files, the ride-key grammar that broke within the hour of being copied,
`SUNK` read by two halves of one shop. `pig_uv.py` exists for exactly this
reason one level down, and `skin_colours.py` for the same reason again.

The test is whether the next reorganisation is a diff in ONE file. It was --
the 2026-09-22 move of every skin out of `blender/pig/skins/<key>/` into
`assets/piggies/<tier>/<key>/`, and the same day's move of every import package out
of `assets/skins/animal/<tier>/<key>/` into `assets/piggies/<tier>/<key>/package/`,
were this file plus the scripts that had grown their own copies of the old
literals.

A SKIN OWNS A FOLDER UNDER ITS TIER, THE FOLDER HAS FIVE ROOMS, AND
EVERYTHING IN IT IS NAMED AFTER THE SKIN.

    assets/piggies/common/tiger/manifest.json                 key, Config row, pack, ids, sources
    assets/piggies/common/tiger/source/tiger.blend            what you open and turn dials in
    assets/piggies/common/tiger/source/tiger_closed.blend     the same scene with the hatch filled
    assets/piggies/common/tiger/source/coat-spec.json         a rare coat's palette (not every skin)
    assets/piggies/common/tiger/generate/make_tiger_blend.py  the generator, and every number in it
    assets/piggies/common/tiger/sheets/tiger_body_color.png   the two sheets that get uploaded
    assets/piggies/common/tiger/sheets/tiger_trim_color.png
    assets/piggies/common/tiger/sheets/tiger_body_color.open-hatch.png   the sheet the live id points at
    assets/piggies/common/tiger/preview/tiger_view.blend      the game-lit preview scene
    assets/piggies/common/tiger/preview/tiger_hero.png        renders
    assets/piggies/common/tiger/package/tiger-complete.fbx    the DERIVED import package
                                                              (`make/package_animal.py`'s output)

THE TIER IS THE FOLDER A KEY IS FOUND IN, NEVER A LOOKUP IN CONFIG. The
folders were sorted by `Config.SKINS.<key>.rarity` on 2026-09-22 (designer),
with `unreleased/` for a key that has no row yet -- but every resolver below
finds a key by SEARCHING the tier folders and reports the tier it found it
in, so the scripts keep working with no Luau in the loop and a folder that
is moved between tiers by hand is simply found in its new one. A key that
exists nowhere is born under `unreleased/`, which is what a new coat is.

which is why `skin_blend` takes a KEY rather than a filename: the folder, the
scene and both maps are all derivable from it, so there is no way to put a
tiger's blend in the bee's folder. `bake_skin.py` therefore needs `--skin` and
nothing else, where it used to need `--blend` as well and would cheerfully bake
one skin's materials into another skin's sheets if the two disagreed.

THE FOUR LEGENDARIES AND THE SHARED `metal/` PACK ARE IN HERE TOO NOW (folded
in later the same day, once their rebuild finished). `skin_dir` still falls
back to `blender/pig/skins/<key>` for a key that has a folder there and none
under `assets/piggies/` -- nothing does today -- so a folder somebody ever puts
back under `skins/` keeps resolving flat rather than silently landing nowhere.

`find` IS THE COMPATIBILITY HALF, and it exists because a person typing a
command should not have to know this file. Anything named on a command line is
looked for as given, then in `pig/`, then in every piggy's rooms, then in any
legacy skin folder -- so `--blend pig_parts.blend` and `--blend tiger.blend`
both resolve, and a name that matches nothing raises HERE, naming what was
searched, rather than failing inside Blender as a file-open error twenty lines
later.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# THE REPOSITORY ROOT, derived rather than assumed: `blender/pig/` is two
# levels under it, and the piggies live under `assets/`, which is beside
# `blender/` rather than inside it.
REPO = os.path.dirname(os.path.dirname(HERE))

# THE ANIMAL. Scene files and the .obj exports that are actually uploaded.
# Those two kinds sit together on purpose: an export is a fact about a
# particular scene, and separating them is how a stale .obj ends up beside a
# rebuilt .blend with nothing to say they disagree.
PIG = os.path.join(HERE, "pig")

# THE PIGGIES. One folder each under its tier; see the header and
# `assets/piggies/README.md`. `TIERS` is the order the folders are searched
# in and the order a listing prints them.
PIGGIES = os.path.join(REPO, "assets", "piggies")
TIERS = ("common", "rare", "epic", "legendary", "unreleased")

# THE OLD SKIN FOLDERS. Empty of skins since 2026-09-22 (only the README and
# the designer's copies to clean up); `SKINS` keeps its old name because
# scripts outside this file still read it as "the legacy root".
LEGACY_SKINS = os.path.join(HERE, "skins")
SKINS = LEGACY_SKINS

# THE TIER GALLERIES. `assets/skins/animal/<tier>/` still holds the tier
# index pages the gallery builders write (index.html, manifest.json,
# README.md); the packages those pages link to live under the piggies.
TIER_GALLERIES = os.path.join(REPO, "assets", "skins", "animal")

# PICTURES. Everything in here is one command away from being remade, which is
# why `.gitignore` refuses the whole folder.
RENDERS = os.path.join(HERE, "renders")

for _d in (PIG, RENDERS):
    os.makedirs(_d, exist_ok=True)

# The master scene every skin is built from, and the raw generator output it
# comes from. Named here rather than spelled in each caller.
PARTS = os.path.join(PIG, "pig_parts.blend")
RAW = os.path.join(PIG, "pig.blend")

# The five rooms of a piggy folder. Named once so the README, the manifests
# and every resolver below agree about the words.
ROOMS = ("source", "generate", "sheets", "preview", "package")


def pig(name):
    """A file in `pig/` -- a scene or a mesh export."""
    return os.path.join(PIG, name)


def _tier_dirs():
    """The tier folders in search order: the five named ones, then any other
    folder somebody adds under `assets/piggies/` (a tier this file has not
    heard of still resolves; it just sorts last)."""
    seen = list(TIERS)
    if os.path.isdir(PIGGIES):
        for d in sorted(os.listdir(PIGGIES)):
            if os.path.isdir(os.path.join(PIGGIES, d)) and d not in seen and not d.startswith((".", "_")):
                seen.append(d)
    return seen


def _find(key):
    """`(tier, dir)` for a key that has a folder under some tier, else None.
    Raises if it is found in more than one, because two folders for one key
    is two sources of truth."""
    hits = [(t, os.path.join(PIGGIES, t, key)) for t in _tier_dirs()
            if os.path.isdir(os.path.join(PIGGIES, t, key))]
    if len(hits) > 1:
        raise RuntimeError("%r is in more than one tier folder: %s" % (key, ", ".join(t for t, _ in hits)))
    return hits[0] if hits else None


def tier_of(key):
    """The tier folder a key is FOUND in (`common`, `rare`, `epic`,
    `legendary`, `unreleased`), or None for a key with no folder anywhere.
    Derived from the folder, never from Config: see the header."""
    hit = _find(key)
    return hit[0] if hit else None


def is_legacy(key):
    """True for a key that still lives in `blender/pig/skins/<key>/` and has
    no folder under any tier of `assets/piggies/`. Nothing is, since the
    legendaries and `metal/` were folded in; kept so a folder that is ever
    put back there still resolves flat instead of landing nowhere."""
    return _find(key) is None and os.path.isdir(os.path.join(LEGACY_SKINS, key))


def skin_dir(key):
    """A skin's folder, made if it is not there yet.

    `assets/piggies/<tier>/<key>/` for every skin that has one, whichever
    tier it is found under; `assets/piggies/unreleased/<key>/` for a skin
    that does not exist yet, so a new coat is born where a coat with no
    Config row belongs. `blender/pig/skins/<key>/` only for a key that is
    still there and nowhere else (see the header).
    """
    hit = _find(key)
    if hit:
        return hit[1]
    if is_legacy(key):
        return os.path.join(LEGACY_SKINS, key)
    d = os.path.join(PIGGIES, "unreleased", key)
    os.makedirs(d, exist_ok=True)
    return d


def room(key, name):
    """`assets/piggies/<tier>/<key>/<room>/`, made on demand. A legacy key has no
    rooms: its one flat folder answers for all of them, which is the layout
    its scripts were written against."""
    assert name in ROOMS, name
    d = skin_dir(key)
    if is_legacy(key):
        return d
    d = os.path.join(d, name)
    os.makedirs(d, exist_ok=True)
    return d


def skin_source_dir(key):
    return room(key, "source")


def skin_generate_dir(key):
    return room(key, "generate")


def skin_sheets_dir(key):
    return room(key, "sheets")


def skin_preview_dir(key):
    return room(key, "preview")


def skin_package_dir(key):
    """`assets/piggies/<tier>/<key>/package/` -- the DERIVED import package: the
    `-complete.blend`/`.fbx`, the studio renders, the asset report, the
    crate card, and for a legendary its idle FBX, motion frames and helper
    Luau. Written by `make/package_animal.py` and the legendary builders FROM
    the other rooms, never the other way round -- so it lives beside them
    rather than being the source of anything."""
    return room(key, "package")


def manifest(key):
    """`assets/piggies/<tier>/<key>/manifest.json` -- what the skin is, which Config
    row and which SurfacePacks templates it feeds, the ids those carry today,
    and which files in this folder are the sources of those ids."""
    return os.path.join(skin_dir(key), "manifest.json")


def skin_blend(key):
    """`source/<key>.blend` -- the authored scene, always. This is what the
    generator WRITES and what a hand edit opens."""
    return os.path.join(skin_source_dir(key), key + ".blend")


def skin_closed_blend(key):
    """`source/<key>_closed.blend` -- the authored scene with the vault hatch
    filled by `make/closedback_fill.py`. Same UVs as `<key>.blend` plus one
    island for the fill, which is why the body sheet baked from it is the
    CURRENT one (see `skin_bake_blend`)."""
    return os.path.join(skin_source_dir(key), key + "_closed.blend")


def skin_bake_blend(key):
    """THE SCENE A BAKE SHOULD OPEN: the closed-back one where it exists, the
    open one otherwise.

    The designer's call of 2026-09-22 is that the closed-back body sheet is
    the current truth, and it can only be baked from the closed scene -- on
    the open scene the fill's island is unbaked and renders as a black disc
    on the rump. The generators still write the OPEN scene, because the
    master they copy is still open; the moment `pig_parts.blend` is filled
    the two collapse into one file and this prefers it automatically.
    `bake_skin.py --blend` overrides it, as it always did.
    """
    closed = skin_closed_blend(key)
    return closed if os.path.exists(closed) else skin_blend(key)


def skin_script(key):
    """`generate/make_<key>_blend.py` -- the generator."""
    return os.path.join(skin_generate_dir(key), "make_%s_blend.py" % key)


def coat_spec(key):
    """`source/coat-spec.json` -- a rare coat's palette and its parent scene's
    hash, written by `make/build_rare_coat.py`. Not every skin has one."""
    return os.path.join(skin_source_dir(key), "coat-spec.json")


def sheet(key, filename):
    """A file in the skin's `sheets/` room by its full name -- for the packs
    that carry more than the two colour sheets (diamond's normal and
    roughness maps, the metal pack's five)."""
    return os.path.join(skin_sheets_dir(key), filename)


def skin_map(key, group):
    """`sheets/<key>_<group>_color.png`, for group `body` or `trim`.

    The engine wants two sheets because the game ships a `Body` MeshPart and a
    joined `Trim` MeshPart with separate colours, so this is the game's own
    split rather than a filing choice.
    """
    return sheet(key, "%s_%s_color.png" % (key, group))


def skin_open_hatch_map(key, group):
    """`sheets/<key>_<group>_color.open-hatch.png` -- the sheet baked against
    the OPEN-hatch body, which is the one every live `ColorMap` id was
    uploaded from. Kept beside the current (closed-back) sheet and written by
    nothing: it is the record of what the id points at, and the day the
    closed sheet is uploaded it is the one to retire. (The legendaries the
    other workstream closed keep theirs as `<name>.before-closedback.png`.)"""
    return sheet(key, "%s_%s_color.open-hatch.png" % (key, group))


def skin_alpha(key, group):
    """`sheets/<key>_<group>_alpha.png` -- the animated-skin mask
    `make/bake_alpha.py` writes and `make/apply_alpha.py` folds in."""
    return sheet(key, "%s_%s_alpha.png" % (key, group))


def skin_emissive(key, group):
    """`sheets/<key>_<group>_emissive.png` -- a glow mask. The rare coats
    retired theirs; the name is kept for the packagers that still look."""
    return sheet(key, "%s_%s_emissive.png" % (key, group))


def skin_view(key):
    """`preview/<key>_view.blend` -- the game-lit preview scene.

    NAMED AFTER THE SKIN, WHICH IS WHAT MAKES TWO SKINS SAFE TO WORK ON AT
    ONCE. It was one shared `pig_view.blend`, and a shared name written by a
    PER-SKIN script is a collision waiting for the second person: two previews
    running together would each open the other's half-written scene, and the
    symptom is a picture of the wrong animal rather than an error.
    """
    return os.path.join(skin_preview_dir(key), key + "_view.blend")


def skin_preview(key, name):
    """A picture in the skin's `preview/` room -- `<key>_hero.png`,
    `<key>_hatch.png`, the shop card."""
    return os.path.join(skin_preview_dir(key), name)


def skin_study(key, name):
    """A design study or concept set kept with the generator --
    `generate/<name>/`: the rainbow tiger's `beard-shape-study` and
    `rainbow-tiger-concept`, the phoenix's `concepts-v2`. Inputs a builder
    reads, so they live in the room of the thing that reads them."""
    return os.path.join(skin_generate_dir(key), name)


def skin_keys(need_body_sheet=False):
    """Every key that has a folder under `assets/piggies/`, plus any legacy
    key still under `blender/pig/skins/`. With `need_body_sheet`, only those
    whose body colour sheet has been baked -- which is what the checks that
    walk the whole catalogue want."""
    keys = set()
    for t in _tier_dirs():
        base = os.path.join(PIGGIES, t)
        if os.path.isdir(base):
            keys.update(d for d in os.listdir(base)
                        if os.path.isdir(os.path.join(base, d))
                        and not d.startswith((".", "_")))
    if os.path.isdir(LEGACY_SKINS):
        keys.update(d for d in os.listdir(LEGACY_SKINS)
                    if os.path.isdir(os.path.join(LEGACY_SKINS, d))
                    and not d.startswith((".", "_")))
    keys = sorted(keys)
    if need_body_sheet:
        keys = [k for k in keys if os.path.exists(skin_map(k, "body"))]
    return keys


def tier_gallery(tier):
    """`assets/skins/animal/<tier>/` -- where a tier's index.html,
    manifest.json and README.md are written. The packages they list are
    `skin_package_dir(key)`; `tier_gallery('.')` is the top-level page."""
    d = os.path.normpath(os.path.join(TIER_GALLERIES, tier))
    os.makedirs(d, exist_ok=True)
    return d


def animal_package(key):
    """The DERIVED import package -- `assets/piggies/<tier>/<key>/package/`. It was
    `assets/skins/animal/<tier>/<key>/` until 2026-09-22; the tier is still
    what `tier_of` says, it simply no longer decides where the files are."""
    return skin_package_dir(key)


def render(name):
    """A picture. The folder is made on demand so no script has to."""
    os.makedirs(RENDERS, exist_ok=True)
    return os.path.join(RENDERS, name)


def _search_dirs():
    dirs = [os.getcwd(), HERE, PIG]
    for t in _tier_dirs():
        tdir = os.path.join(PIGGIES, t)
        if not os.path.isdir(tdir):
            continue
        for key in sorted(os.listdir(tdir)):
            base = os.path.join(tdir, key)
            if not os.path.isdir(base):
                continue
            for r in ROOMS:
                d = os.path.join(base, r)
                if os.path.isdir(d):
                    dirs.append(d)
    if os.path.isdir(LEGACY_SKINS):
        dirs += [os.path.join(LEGACY_SKINS, d) for d in sorted(os.listdir(LEGACY_SKINS))
                 if os.path.isdir(os.path.join(LEGACY_SKINS, d))]
    return dirs


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
    for base in _search_dirs():
        p = os.path.join(base, name)
        tried.append(p)
        if os.path.exists(p):
            return p
    raise RuntimeError("no %s called %r. Looked in:\n  %s"
                       % (kind, name, "\n  ".join(tried)))
