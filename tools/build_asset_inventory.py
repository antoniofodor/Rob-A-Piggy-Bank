#!/usr/bin/env python3
"""Write docs/ASSET-INVENTORY.md: everything this game uploads, builds or has retired.

    python tools/build_asset_inventory.py

GENERATED, NOT MAINTAINED BY HAND, for the reason every other derived list in
this project is: a hand-written inventory is wrong the first time somebody adds
a mesh and does not update it, and a wrong inventory is worse than none -- it
is the thing you would delete an asset from your own account on the strength
of. The one hand-kept part is RETIRED below, because "why it went" is knowledge
no scan can recover.

What it is FOR: every `rbxassetid` in here is an upload sitting on the
developer's own Roblox account. That is the list to work from when deciding
what to keep, re-use or delete -- and CLAUDE.md records why that matters more
than it sounds (a generated-asset moderation strike lands on the ACCOUNT, not
the experience).
"""
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'src'

# WHAT WENT, WHY, AND WHETHER ITS GEOMETRY IS STILL HERE.
#
# A retirement in this project takes an item's CATALOGUE ROW and deliberately
# leaves its builder, so anything here can come back as one line -- and a few
# are still built for something else entirely (the resident figures).
RETIRED = [
    ('Giant Rubber Duck', 'bigduck', 'Decor.luau builders.bigduck',
     'Sept 2026: meme ornaments pulled off the lawn while the yard has no direction.'),
    ('Swole Gnome', 'buffgnome', 'Decor.luau builders.buffgnome', 'as above'),
    ('Wacky Waving Man', 'tubeman', 'Decor.luau builders.tubeman', 'as above'),
    ('Loo Guy', 'looguy', 'Decor.luau builders.looguy', 'as above'),
    ('Shark In Trainers', 'sharkshoes', 'Decor.luau builders.sharkshoes', 'as above'),
    ('Brace Face', 'bracestatue', 'Decor.luau builders.bracestatue', 'as above'),
    ('Drip Statue', 'dripstatue', 'Decor.luau builders.dripstatue',
     'as above -- AND STILL IN USE: every resident is built from this geometry through '
     '`Decor.buildFigure`, and the statue itself is wanted somewhere on the map.'),
    ('Wheelie Bins', 'bins', 'Decor.luau builders.bins',
     'Became public street furniture; selling a lookalike would put two objects on the '
     'street a player cannot tell apart. Reached through `Decor.buildStreetBin`.'),
    ('Hatchback / Sports Car', 'car', 'removed',
     'Retired with the whole driveway decor zone.'),
    ('Disguise Kit', 'disguise', 'ThiefModel.luau builders.disguise',
     'Never worked -- its prop named a key that was not in the catalogue, so it failed '
     'silently. The public bins deliver the same fantasy.'),
    ('Guard Dog upgrade', 'UPGRADES.dog', 'GuardDog.luau / DOG_TIERS kept',
     'Rung retired; every plot has the same dog (`Config.DOG_LEVEL`) and variety comes '
     'from coats. All five breed rigs are still built and still uploaded.'),
    ('The trophy shelf, all ten', 'TROPHIES', 'Decor.luau trophy builders',
     'Sept 2026: the whole trophy layer retired for the MVP. A trophy model has DEPTH, '
     'so hung in a framed wall cell its edges cut through the frame and its neighbour, '
     'and one cell cannot hold ten differently shaped objects. Replaced by three stat '
     'panels (skins robbed, coins stolen, patrols outrun) and a wanted poster. EVERY '
     'COUNTER SURVIVES in `data.trophies` -- the panels read four of them.'),
    ('The lawn ornaments, all twelve', 'DECOR_ITEMS', 'Decor.luau builders',
     'Sept 2026: the yard has no direction. The memes went, the trophies went with the '
     'trophy room, and what was left served no loop -- not defended, not robbed, not '
     'read from the pavement. `DECOR_SLOTS` is kept (nine coordinates, free to leave '
     'empty). THREE BUILDERS ARE STILL REACHED DIRECTLY and must not be removed: '
     '`buildFigure` (every resident on the street), `buildStreetBin` (the kerb bins) '
     'and `buildMailbox` (every plot).'),
    ('The garden: borders, paths, window boxes', 'BORDER_PLANTS / GARDEN_PATHS / WINDOW_BOXES',
     'Decor.luau buildBorder / buildPath / buildWindowBoxes',
     'Equipped rather than placed, so they spent no lawn slot -- an argument about slots, '
     'which stopped being a question once nothing is placed in them.'),
    ('Crashed Drone, from the alien set', 'SETS.alien items', 'Decor.luau builders.crashedDrone',
     'Went with the lawn ornaments. The set is two items now, a skin and a ride; a set is '
     'a VIEW over the catalogues, so this was one line and no ownership to migrate.'),
    ('Trophy plinth finishes', 'TROPHY_PLINTHS', 'Decor.luau trophyPlinth',
     'The only thing they painted was a trophy plinth, and there is no trophy standing '
     'anywhere. Six prices that bought something invisible. `trophies.plinth` and '
     '`.plinths` are pruned against the empty table.'),
]

# Where a code-built model comes from: module -> the pattern its builders match.
BUILDER_TABLES = {
    'Decor.luau': r'^builders\.(\w+) = function',
    'House.luau': r'^(?:builders|rebuilt)\.(\w+) = function',
    'PetModel.luau': r'^builders\.(\w+) = function',
    'ThiefModel.luau': r'^builders\.(\w+) = function',
    'GadgetModel.luau': r'^builders\.(\w+) = function',
    'BoneModel.luau': r'^builders\.(\w+) = function',
    'RideModel.luau': r'^builders\.(\w+) = function',
    'UpgradePreview.luau': r'^builders\.(\w+) = function',
}

ID = re.compile(r'rbxassetid://(\d+)')
KEY = re.compile(r'^\s*\[?"?(\w+)"?\]?\s*=')
TABLE = re.compile(r'^Config\.([A-Z_0-9]+) = \{')
ENTRY = re.compile(r'^\t(\w+) = \{')
# A row of a LIST-shaped ladder: a bare `{` or a one-line `{ ... }`.
ROW = re.compile(r'^\t\{')
LABEL = re.compile(r'label = "([^"]+)"')
IDFIELD = re.compile(r'id = "([^"]+)"')
NAME = re.compile(r'name = "([^"]+)"')


def luau_files():
    return sorted(SRC.rglob('*.luau'))


def scan_ids():
    """Every uploaded asset id, with the nearest label above it."""
    found = defaultdict(list)
    for path in list(luau_files()) + sorted(SRC.rglob('*.rbxmx')):
        lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
        section = ''
        for i, line in enumerate(lines):
            table = TABLE.match(line)
            if table:
                section = table.group(1)
            for asset in ID.findall(line):
                label = ''
                key = KEY.match(line)
                if key:
                    label = key.group(1)
                if not label:
                    # An id on its own line (a .rbxmx `<url>`): look up for a name.
                    for back in range(i, max(i - 8, -1), -1):
                        named = NAME.search(lines[back]) or KEY.match(lines[back])
                        if named:
                            label = named.group(1)
                            break
                rel = path.relative_to(ROOT).as_posix()
                found[asset].append((rel, i + 1, section, label))
    return found


def scan_builders():
    out = {}
    for name, pattern in BUILDER_TABLES.items():
        matches = []
        for path in luau_files():
            if path.name != name:
                continue
            rx = re.compile(pattern)
            for line in path.read_text(encoding='utf-8').splitlines():
                m = rx.match(line)
                if m and m.group(1) not in matches:
                    matches.append(m.group(1))
        if matches:
            out[name] = sorted(matches)
    return out


def scan_catalogues():
    """Config tables of buyable/ownable things, with their entries."""
    wanted = ('SKINS', 'EFFECTS', 'ACCESSORIES', 'DECOR_ITEMS', 'RIDES', 'PETS',
              'HOUSE_TIERS', 'FENCE_TIERS', 'LOCK_TIERS', 'DOG_TIERS', 'DOG_COATS',
              'DOG_KENNELS', 'DOG_TOYS', 'CATCH_EFFECTS', 'TROPHY_PLINTHS', 'TROPHIES',
              'BONES', 'GADGETS', 'HOME_ITEMS', 'THIEF_KIT', 'GEAR', 'BORDER_PLANTS',
              'GARDEN_PATHS', 'WINDOW_BOXES', 'CHESTS', 'PASSES', 'FINISHES',
              'SIGN_WORDS', 'UPGRADES')
    config = (SRC / 'ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf-8')
    lines = config.splitlines()
    out = {}
    current = None
    for line in lines:
        table = TABLE.match(line)
        if table:
            current = table.group(1) if table.group(1) in wanted else None
            if current:
                out[current] = []
            continue
        if line.startswith('}'):
            current = None
        if current:
            entry = ENTRY.match(line)
            if entry:
                out[current].append(entry.group(1))
                continue
            # LIST-SHAPED TABLES TOO. The ladders -- HOUSE_TIERS, FENCE_TIERS,
            # LOCK_TIERS, DOG_TIERS -- are ARRAYS rather than keyed tables, so
            # a key pattern alone matched none of them and the inventory
            # quietly left out every house, fence, lock and breed in the game.
            # That is the "a wrong inventory is worse than none" failure this
            # script's own header warns about, met on the first run.
            if ROW.match(line):
                out[current].append('#%d' % (len(out[current]) + 1))
            named = NAME.search(line) or LABEL.search(line) or IDFIELD.search(line)
            if named and out[current] and ':' not in out[current][-1]:
                out[current][-1] += ': ' + named.group(1)
    return {k: v for k, v in out.items() if v}


def main():
    ids = scan_ids()
    builders = scan_builders()
    catalogues = scan_catalogues()

    lines = ['# Asset inventory', '',
             '**Generated by `tools/build_asset_inventory.py`. Do not edit by hand** --',
             're-run it after adding or retiring anything. The RETIRED table at the',
             'bottom is the one part the script keeps, because why something went is',
             'not something a scan can recover.', '',
             'Three kinds of thing live here, and only the first one costs anything to',
             'keep: an **upload** sits on the developer\'s own Roblox account, a',
             '**builder** is geometry written in Luau and costs nothing but code, and a',
             '**catalogue entry** is a row players can own.', '']

    lines += ['## Uploads (%d assets)' % len(ids), '',
              'Every `rbxassetid` referenced anywhere in `src/`. These are the ones to',
              'work from when deciding what to delete -- and note CLAUDE.md\'s warning',
              'that a moderation strike on a generated upload lands on the ACCOUNT.', '',
              '| id | used as | where |', '| --- | --- | --- |']
    for asset in sorted(ids, key=lambda a: int(a)):
        uses = ids[asset]
        label = next((f'{s}.{l}' if s else l for _, _, s, l in uses if l), '?')
        where = ', '.join(sorted({f'{rel}:{line}' for rel, line, _, _ in uses})[:3])
        if len({f'{rel}:{line}' for rel, line, _, _ in uses}) > 3:
            where += ', ...'
        lines.append(f'| `{asset}` | {label} | {where} |')

    lines += ['', '## Code-built models', '',
              'Nothing here is uploaded: it is geometry in Luau, so it can be changed,',
              'retired or rebuilt for free.', '']
    for module, keys in sorted(builders.items()):
        lines.append(f'**{module}** ({len(keys)}): ' + ', '.join(f'`{k}`' for k in keys))
        lines.append('')

    lines += ['## Catalogues', '',
              'What a player can own, by the Config table that defines it.', '']
    for table, entries in sorted(catalogues.items()):
        lines.append(f'### Config.{table} ({len(entries)})')
        lines.append('')
        for entry in entries:
            lines.append(f'- `{entry}`')
        lines.append('')

    lines += ['## Retired', '',
              'Taken out of the catalogues. Geometry is kept unless the note says',
              'otherwise, so any of these is one row away from returning.', '',
              '| what | key | geometry | why |', '| --- | --- | --- | --- |']
    for what, key, geometry, why in RETIRED:
        lines.append(f'| {what} | `{key}` | {geometry} | {why} |')
    lines.append('')

    out = ROOT / 'docs/ASSET-INVENTORY.md'
    out.write_text('\n'.join(lines), encoding='utf-8', newline='\n')
    print(f'{len(ids)} uploads, '
          f'{sum(len(v) for v in builders.values())} builders, '
          f'{sum(len(v) for v in catalogues.values())} catalogue entries, '
          f'{len(RETIRED)} retired')
    print(f'wrote {out.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
