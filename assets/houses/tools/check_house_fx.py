#!/usr/bin/env python3
"""Audit the authored house effects against what the runtime can actually read.

    python assets/houses/tools/check_house_fx.py

Exits non-zero on a real fault. WRITTEN BECAUSE THREE OF THESE SHIPPED AT ONCE
and every one was silent -- no error, no warning, an effect that simply never
ran. An audit is only worth the question it asks, so these are the four
questions those three faults were:

  1. IS THE SPEC KEYED THE WAY IT IS READ? `House.buildTemplateHouse` looks up
     `HouseFXSpec[tier.style]`, and two ids are not their style: `neontower` is
     `tower` and `skycastle` is `castle`. Keyed by id, the Neon Tower's twenty
     effects and the Sky Castle's seventeen went to nobody.
  2. DOES EVERY ROW CARRY A COLOUR? Every colour branch in `HouseFX.step`
     builds `Color3.fromHSV(hue, sat, ...)` and ignores the part's own colour,
     and `Hue` defaults to 0 -- RED. A row without `Hue`/`Sat` does not keep the
     artist's colour, it overwrites it every frame.
  3. IS EVERY AUTHORED FX MESH COVERED? A handoff read for one key missed the
     Gloop House entirely, which carries `drips` rather than `effects` -- three
     meshes named `HouseFX_*` that nothing animated.
  4. DOES EVERY ROW NAME A PART THAT EXISTS? A mesh renamed in Blender silently
     stops animating, because the spec is matched by name.

What it does NOT do is check that an effect LOOKS right. Nothing offline can,
and this file should not pretend otherwise: `Rate` within the flash ceiling and
a hue in the blue range are properties of numbers, not of a picture.
"""
import re
import sys
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / 'src/ReplicatedStorage/Shared'
# `HouseFX.MAX_RATE` clamps anything faster, so this is the point at which the
# clamp starts silently disagreeing with what the art asked for.
MAX_RATE = 0.9


def table(text, name):
    start = text.index('Config.%s = {' % name)
    depth, i = 0, text.index('{', start)
    for j in range(i, len(text)):
        if text[j] == '{':
            depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0:
                return text[i:j]
    raise SystemExit('unterminated Config.%s' % name)


def main():
    config = (SRC / 'Config.luau').read_text(encoding='utf-8')
    tiers = table(config, 'HOUSE_TIERS')
    style_of, styles = {}, set()
    for chunk in tiers.split('\t\tid = "')[1:]:
        found = re.search(r'style = "(\w+)"', chunk)
        if found:
            style_of[chunk.split('"')[0]] = found.group(1)
            styles.add(found.group(1))
    rows = dict(re.findall(r'^\t(\w+) = "(\w+)"', table(config, 'HOUSE_TEMPLATE'), re.M))

    spec = (SRC / 'HouseFXSpec.luau').read_text(encoding='utf-8')
    blocks = dict(re.findall(r'\n\t(\w+) = \{(.*?)\n\t\},', spec, re.S))

    problems, notes = [], []

    for style in sorted(blocks):
        if style not in styles:
            problems.append('spec key %r is not a tier style -- it will never be read' % style)
        elif style not in rows:
            problems.append('spec key %r has no Config.HOUSE_TEMPLATE row' % style)

    parts_of = {}
    for path in sorted((SRC / 'HouseTemplates').glob('*.rbxmx')):
        slug = path.stem
        root = ElementTree.parse(path).getroot()
        names = [item.find('Properties').find("string[@name='Name']").text
                 for item in root.iter('Item') if item.get('class') == 'MeshPart']
        parts_of[style_of.get(slug, slug)] = (slug, names)

    total = 0
    for style, body in sorted(blocks.items()):
        entries = re.findall(r'\["([^"]+)"\] = \{ ([^}]+)\}', body)
        total += len(entries)
        known = parts_of.get(style)
        for name, fields in entries:
            if 'Hue = ' not in fields or 'Sat = ' not in fields:
                problems.append('%s/%s has no Hue/Sat -- it will render RED' % (style, name))
            rate = re.search(r'Rate = ([\d.]+)', fields)
            if rate and float(rate.group(1)) > MAX_RATE:
                problems.append('%s/%s Rate %s is past the flash ceiling'
                                % (style, name, rate.group(1)))
            if known and name not in known[1]:
                problems.append('%s/%s names no mesh in %s.rbxmx' % (style, name, known[0]))

    for style, (slug, names) in sorted(parts_of.items()):
        covered = set(re.findall(r'\["([^"]+)"\]', blocks.get(style, '')))
        loose = [n for n in names if n.startswith('HouseFX') and n not in covered]
        if loose:
            problems.append('%s has %d authored FX mesh(es) covered by nothing: %s'
                            % (slug, len(loose), ', '.join(sorted(loose))))

    # INERT RATHER THAN BROKEN, and reported every run so it cannot be forgotten:
    # a kind with no branch in the animator carries its data and does nothing.
    branches = set(re.findall(r'fx == "(\w+)"', (SRC / 'HouseFX.luau').read_text(encoding='utf-8')))
    for style, body in sorted(blocks.items()):
        for kind in sorted(set(re.findall(r'FX = "(\w+)"', body))):
            if kind not in branches:
                notes.append('%s uses %r, which has no branch in HouseFX.step -- inert'
                             % (style, kind))

    print('%d effect meshes across %d houses' % (total, len(blocks)))
    for note in notes:
        print('  note: %s' % note)
    if problems:
        print('\n%d PROBLEM(S):' % len(problems))
        for problem in problems:
            print('  %s' % problem)
        return 1
    print('every row is keyed by a real style, carries a colour, names a real mesh, '
          'and no authored FX mesh is uncovered.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
