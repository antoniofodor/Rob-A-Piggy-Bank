#!/usr/bin/env python3
"""Which uploads this repo still points at, and which are orphans.

    python tools/groom_uploads.py

READ-ONLY. It deletes nothing and it cannot: a Roblox mesh upload is an asset on
the developer's own account and there is no API in this toolchain that removes
one. What this produces is the LIST to work from by hand, which is the same job
`build_asset_inventory.py` describes for the live set -- this is the other half,
the ids that were uploaded and are no longer referenced by anything.

WHY IT IS WORTH HAVING. Every house import uploads one mesh per material, so a
re-export at a new revision orphans the whole previous set: the v1 house imports
alone are about ninety meshes that nothing will ever read again. They cost
nothing to leave, and they make the account impossible to audit -- which is what
a moderation strike makes suddenly expensive, because CLAUDE.md records that it
lands on the ACCOUNT rather than on the experience.

THE ONE THING NOT TO DO WITH THIS OUTPUT is delete an id because it is missing
from `src/`. An id can be live and absent from source: a template that has not
been regenerated yet, an asset referenced only from a place file, or a peer
session's uncommitted work. Cross-check against `git status` before touching
anything, and prefer ARCHIVING an asset to deleting it.
"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ID = re.compile(r'rbxassetid://(\d+)')


def referenced():
    """Every id `src/` points at, with the files that point at it."""
    out = defaultdict(set)
    for path in (ROOT / 'src').rglob('*'):
        if path.is_file() and path.suffix in ('.luau', '.rbxmx', '.json'):
            try:
                text = path.read_text(encoding='utf-8')
            except UnicodeDecodeError:
                continue
            for asset in ID.findall(text):
                out[asset].add(str(path.relative_to(ROOT)))
    return out


def uploaded():
    """Every id a recorded house import ever produced, by asset folder.

    `studio-import.json` is the only record of what an import uploaded, which is
    what makes a superseded revision's meshes findable at all.
    """
    out = defaultdict(set)
    for path in (ROOT / 'assets').rglob('studio-import.json'):
        folder = path.parent.name
        for part in json.loads(path.read_text(encoding='utf-8')).get('parts', []):
            found = ID.findall(part.get('mesh', ''))
            if found:
                out[found[0]].add(folder)
    return out


def superseded():
    """Asset folders with a higher revision of the same house beside them."""
    houses = defaultdict(list)
    base = ROOT / 'assets/houses'
    for path in sorted(base.iterdir()):
        if path.is_dir() and '-v' in path.name and path.name.rsplit('-v', 1)[1].isdigit():
            name, rev = path.name.rsplit('-v', 1)
            houses[name].append(int(rev))
    return {f'{name}-v{r}': f'{name}-v{max(revs)}'
            for name, revs in houses.items() for r in revs if r != max(revs)}


def main():
    live, up, old = referenced(), uploaded(), superseded()
    orphans = {a: f for a, f in up.items() if a not in live}

    print('UPLOADS RECORDED BY A HOUSE IMPORT: %d, of which %d are still referenced '
          'by src/ and %d are ORPHANS' % (len(up), len(up) - len(orphans), len(orphans)))
    by_folder = defaultdict(list)
    for asset, folders in orphans.items():
        by_folder[', '.join(sorted(folders))].append(asset)
    for folder in sorted(by_folder):
        ids = sorted(by_folder[folder])
        print('\n  %s -- %d orphaned meshes' % (folder, len(ids)))
        for i in range(0, len(ids), 4):
            print('    ' + '  '.join(ids[i:i + 4]))

    print('\nSUPERSEDED ASSET FOLDERS (a higher revision sits beside them): %d' % len(old))
    for name in sorted(old):
        print('  %-34s superseded by %s' % (name, old[name]))

    print('\nTOTAL ids referenced by src/: %d' % len(live))
    print('Anything above is a CANDIDATE, not a verdict -- read the header.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
