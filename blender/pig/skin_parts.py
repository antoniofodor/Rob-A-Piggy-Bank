# -*- coding: utf-8 -*-
"""Seat a skin's materials on the pig, without destroying the hand work.

ONE FUNCTION, AND IT EXISTS BECAUSE THE OBVIOUS VERSION SILENTLY DELETES A
SELECTION. Two skin scripts each carried the same four lines --

    ob.data.materials.clear()
    for m in mats:
        ob.data.materials.append(m)

-- and `clear()` DOES NOT ONLY EMPTY THE SLOT LIST. It resets every polygon's
`material_index` to 0. So the ear, whose 313 faces were picked out by hand in
edit mode to be the rim, came back with all 3326 faces on slot 0 and the second
material seated on nothing at all.

NOTHING ERRORED AND BOTH FILES OPENED FINE. On the bee the rims went from black
to yellow; on the tiger the inner ear went from pink to whatever the coat was
doing there, which is a plausible-looking dark ear and was read as "the pink
zone is small" rather than as "the pink zone is gone". It was caught by baking
the rebuilt bee and diffing against the shipped map -- 23,174 texels different,
every one of them ink in the original and yellow in the rebuild -- which is the
only reason anybody looked at the slots at all.

**A FACE ASSIGNMENT IS THE ONE THING IN A SKIN THAT NO SCRIPT CAN REGENERATE.**
The node graphs are generated, the bake is derived, the blend is disposable and
the textures are output. The selection somebody made by eye is not, and it does
not live in a place that looks like data -- it is an integer on every polygon,
invisible in the outliner and absent from every diff. It is the same class as
the hand-painted masks under `skins/`, which `.gitignore` goes out of its way
to keep, and it had no such protection.

ASSIGNING INTO A SLOT LEAVES THE INDICES ALONE, which is the whole fix.
`materials[i] = m` swaps what a slot points AT; only `clear()` and `pop()`
renumber the faces underneath.
"""


def assign(bpy, pairs, label):
    """`pairs` is [(object name, [material per slot, in slot order]), ...].

    THE ORDER IS THE CONTRACT. A polygon carries a slot INDEX, so handing back
    the same two materials the other way round paints the inside of the ear on
    the outside -- correct-looking, and wrong, with nothing to say so. Every
    caller writes the list in slot order and this refuses to guess.
    """
    print("")
    print("=== %s ===" % label)
    for name, mats in pairs:
        ob = bpy.data.objects.get(name)
        if not ob:
            raise RuntimeError("no object called %r" % name)
        had = len(ob.data.materials)
        # A SKIN MAY ADD SLOTS AND MAY NEVER DROP ONE. Fewer materials than the
        # mesh already has means somebody made a selection this script has
        # never heard of, and quietly collapsing it is exactly the failure this
        # module is named after -- so it stops instead.
        if had > len(mats):
            raise RuntimeError(
                "%s carries %d material slots and this skin only names %d. "
                "That extra slot is a face selection somebody made by hand; "
                "look at the file before overwriting it." % (name, had, len(mats)))
        for i, m in enumerate(mats):
            if i < len(ob.data.materials):
                ob.data.materials[i] = m
            else:
                ob.data.materials.append(m)
        print("  %-6s %d slot%s -> %s"
              % (name, len(mats), "" if len(mats) == 1 else "s",
                 ", ".join(m.name for m in mats)))
    # ORPHANS GO, or every rebuild leaves the last skin's materials in the file
    # to be picked up by the next person who opens it looking for the graph.
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)


def face_slots(bpy, names):
    """How many faces sit on each slot, per object -- the thing that goes
    wrong invisibly, printed so a rebuild says whether it survived."""
    import collections
    out = []
    for n in names:
        ob = bpy.data.objects.get(n)
        if not ob:
            continue
        c = collections.Counter(p.material_index for p in ob.data.polygons)
        out.append((n, dict(sorted(c.items()))))
    return out
