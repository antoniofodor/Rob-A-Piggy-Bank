#!/usr/bin/env python3
"""Do a house's display mounts fit inside its own room?

    python assets/houses/tools/check_house_room.py treehouse 2 slime 2

A trophy room is a bare shell plus mounts (see assets/houses/docs/TROPHY-DISPLAY-PROPOSAL.md)
and `TrophyRoom` draws every station from the mount names. So the only thing
that can be wrong in the ART is a mount whose display would stand through a
wall, or two mounts whose displays would stand through each other -- neither of
which errors, and neither of which a render taken from the doorway would
necessarily show.

The room is derived from the collision boxes rather than from numbers typed
here, so a house that changes shape is measured against its new shape.
"""
import json
import sys
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug

ROOT = Path(__file__).resolve().parents[3]

# What TrophyRoom occupies at each kind of mount: (width, depth, height) in
# studs, matching FIT and CELL in TrophyRoom.luau.
FOOT = {
    'shelf': (3.4, 2.9, 2.8),
    'featured': (3.6, 3.6, 4.2),
    'wall': (4 * 3.4 + 3 * 0.36, 0.5, 3 * 2.5 + 2 * 0.36),
    'record': (4.0, 2.2, 2.3),
}


def room(boxes):
    """Interior faces, from the innermost face of each named wall."""
    lo = [-1e9, -1e9, -1e9]
    hi = [1e9, 1e9, 1e9]
    for b in boxes:
        name = b['name'].lower()
        x, y, z = b['blenderLocation']
        sx, sy, sz = b['sizeXYZ']
        if 'side' in name:
            if x < 0:
                lo[0] = max(lo[0], x + sx / 2)
            else:
                hi[0] = min(hi[0], x - sx / 2)
        elif 'rear' in name:
            hi[1] = min(hi[1], y - sy / 2)
        elif 'jamb' in name or 'front' in name:
            lo[1] = max(lo[1], y + sy / 2)
        elif 'floor' in name:
            lo[2] = max(lo[2], z + sz / 2)
        elif 'ceil' in name:
            hi[2] = min(hi[2], z - sz / 2)
    return lo, hi


def kind_of(name):
    if name.startswith('Shelf_'):
        return 'shelf'
    return {'Featured': 'featured', 'Wall': 'wall', 'Record': 'record'}.get(name)


def box_of(name, at, yaw):
    kind = kind_of(name)
    if not kind:
        return None
    w, d, h = FOOT[kind]
    # A yaw of 90 or 270 faces a side wall, so the width runs along y.
    if yaw in (90, 270):
        w, d = d, w
    x, y, z = at
    if kind == 'wall':
        return (x - w / 2, y - d / 2, z - h / 2), (x + w / 2, y + d / 2, z + h / 2)
    # Everything else stands ON its mount.
    return (x - w / 2, y - d / 2, z), (x + w / 2, y + d / 2, z + h)


def check(slug, revision):
    out = ROOT / 'assets/houses' / f'{house_slug(slug)}-v{revision}'
    g = json.loads((out / 'geometry-report.json').read_text())
    mounts, yaws = g['mountsBlender'], g.get('mountYawBlender', {})
    lo, hi = room(g.get('collisionBoxesDraft') or g.get('collisionBoxes') or [])
    print(f'--- {slug} v{revision} ---')
    print('  room x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f'
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))

    problems = []
    boxes = {}
    for name in sorted(mounts):
        b = box_of(name, mounts[name], yaws.get(name, 0))
        if not b:
            continue
        boxes[name] = b
        blo, bhi = b
        for i, axis in enumerate('xyz'):
            if blo[i] < lo[i] - 0.2 or bhi[i] > hi[i] + 0.2:
                problems.append('%s: %s %.2f..%.2f outside %.2f..%.2f'
                                % (name, axis, blo[i], bhi[i], lo[i], hi[i]))
        print('  %-16s x %7.2f..%6.2f  y %6.2f..%6.2f  z %6.2f..%6.2f'
              % (name, blo[0], bhi[0], blo[1], bhi[1], blo[2], bhi[2]))
        if name not in yaws:
            problems.append(f'{name}: no yaw authored, so its display faces the rear wall')

    names = sorted(boxes)
    for i, a in enumerate(names):
        for b2 in names[i + 1:]:
            la, ha = boxes[a]
            lb, hb = boxes[b2]
            if all(la[k] < hb[k] - 0.05 and lb[k] < ha[k] - 0.05 for k in range(3)):
                problems.append(f'{a} overlaps {b2}')
    return problems


def main():
    args = sys.argv[1:]
    if len(args) < 2 or len(args) % 2:
        raise SystemExit(__doc__)
    bad = []
    for i in range(0, len(args), 2):
        bad += [f'{args[i]}: {p}' for p in check(args[i], args[i + 1])]
    print()
    if bad:
        print('PROBLEMS:')
        for p in bad:
            print(' -', p)
    else:
        print('clear: every display fits its room and no two overlap')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
