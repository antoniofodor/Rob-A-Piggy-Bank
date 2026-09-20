#!/usr/bin/env python3
"""What actually stands on a plot for every house tier, and what is blocking it.

    python assets/houses/tools/audit_house_wiring.py

WHY THIS IS A SCRIPT. "Are the houses wired up" has four different answers per
tier -- an authored template, a rebuilt builder, an original builder, or the
placeholder block -- and the one thing none of them is visible in is the place
file: importing an FBX in Studio uploads meshes and leaves a model in the
DataModel, which nothing in `src/` reads. So a house can be imported and still
stand as a grey block, with nothing anywhere saying so. This prints the answer
`House.build` will actually take.

THE RESOLUTION ORDER IS `House.build`'S OWN, and it has to stay in step with
it: template, then mesh, then (placeholder | rebuilt | original | placeholder).
A tier flagged `placeholder` stands the block even when a builder exists,
because `Config.residentHouseLevel` reads the same flag and the two must agree.

`Config.HOUSE_TEMPLATE` IS KEYED BY STYLE AND TWO IDS DIFFER FROM THEIR STYLE
(`neontower` is `tower`, `skycastle` is `castle`), which is the one mistake here
that fails silently -- a row keyed by id is a row that matches nothing, and the
tier falls through to the builder with only a warn.
"""
import json
import os
import re
import sys

from pathlib import Path
from house_paths import house_slug
ROOT = str(Path(__file__).resolve().parents[3])
MODELS = os.path.join(ROOT, 'assets/houses')


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding='utf-8') as handle:
        return handle.read()


def table(source, name):
    """The body of a `Config.<name> = { ... }` literal.

    Found by the ASSIGNMENT rather than the name: every one of these tables is
    mentioned in the prose above its neighbours, so `str.index` on the bare name
    lands in a comment and silently returns an empty slice -- which reads as a
    table with no rows in it rather than as a parse failure.
    """
    start = source.index('Config.%s = {' % name)
    depth, i = 0, source.index('{', start)
    for j in range(i, len(source)):
        if source[j] == '{':
            depth += 1
        elif source[j] == '}':
            depth -= 1
            if depth == 0:
                return source[i:j]
    raise SystemExit('unterminated Config.%s' % name)


def main():
    config = read('src/ReplicatedStorage/Shared/Config.luau')
    house = read('src/ReplicatedStorage/Shared/House.luau')

    templates = dict(re.findall(r'^\t(\w+) = "(\w+)"', table(config, 'HOUSE_TEMPLATE'), re.M))
    # `HOUSE_MESH` rows are written `shack = nil` so the whole ladder reads at a
    # glance, and in Luau a nil value is an ABSENT key -- so a parser that takes
    # that text at face value reports nine meshed houses that do not exist.
    meshes = {k: v for k, v in
              re.findall(r'^\t(\w+) = ([^,\n]+)', table(config, 'HOUSE_MESH'), re.M)
              if v.strip() != 'nil'}
    rebuilt_on = set(re.findall(r'^\t(\w+)\b', table(config, 'HOUSE_REBUILD'), re.M))
    builders = set(re.findall(r'^builders\.(\w+)', house, re.M))
    rebuilt = set(re.findall(r'^rebuilt\.(\w+)', house, re.M))
    shipped = {f.rsplit('.', 1)[0]
               for f in os.listdir(os.path.join(ROOT, 'src/ReplicatedStorage/Shared/HouseTemplates'))}

    tiers = []
    for part in table(config, 'HOUSE_TIERS').split('\t\tid = "')[1:]:
        style = re.search(r'style = "(\w+)"', part)
        tiers.append((part.split('"')[0],
                      style.group(1) if style else '?',
                      re.search(r'placeholder = true', part) is not None))

    rows, outstanding = [], []
    for tier_id, style, placeholder in tiers:
        key = templates.get(style)
        if key and key in shipped:
            stands = 'AUTHORED MODEL'
        elif key:
            stands = 'row, NO template'
        elif style in meshes:
            stands = 'single mesh'
        elif placeholder:
            stands = 'PLACEHOLDER BLOCK'
        elif style in rebuilt_on and style in rebuilt:
            stands = 'code (rebuilt)'
        elif style in builders:
            stands = 'code (original)'
        else:
            stands = 'PLACEHOLDER BLOCK'

        # HIGHEST REVISION, NOT THE FIRST ALPHABETICALLY: treehouse and slime
        # each have a v1 sitting beside the v2 that is actually shipped.
        folder = next((d for d in sorted(os.listdir(MODELS), reverse=True)
                       if d.startswith(house_slug(tier_id) + '-v') and
                       os.path.isdir(os.path.join(MODELS, d))), None)
        if stands == 'AUTHORED MODEL':
            blocking = 'done'
        elif not folder:
            blocking = 'no Blender model'
        elif not os.path.exists(os.path.join(MODELS, folder, 'roblox-import-report.json')):
            blocking = 're-export: no colour manifest'
        elif not os.path.exists(os.path.join(MODELS, folder, 'studio-import.json')):
            blocking = 'Studio dump, then template, then row'
        else:
            blocking = 'generate template, then row'
        if blocking != 'done':
            outstanding.append(tier_id)
        rows.append((tier_id, style, stands, folder or '-', blocking))

    width = max(len(r[3]) for r in rows) + 2
    print('%-14s%-14s%-19s%-*s%s' % ('tier id', 'style', 'stands on a plot', width, 'model', 'blocking'))
    for tier_id, style, stands, folder, blocking in rows:
        print('%-14s%-14s%-19s%-*s%s' % (tier_id, style, stands, width, folder, blocking))
    print('\n%d of %d wired; %d outstanding: %s'
          % (len(rows) - len(outstanding), len(rows), len(outstanding), ' '.join(outstanding)))
    return 1 if outstanding else 0


if __name__ == '__main__':
    sys.exit(main())
