#!/usr/bin/env python3
"""Turn every house's `animation-handoff.json` into the runtime FX spec.

    python assets/houses/tools/build_house_fx.py

Writes src/ReplicatedStorage/Shared/HouseFXSpec.luau.

WHY THIS EXISTS AT ALL: the authored effects were inert, and had been since the
first house landed. `HouseFX` finds what to animate through a CollectionService
TAG and reads its behaviour off ATTRIBUTES on the part -- and the template
generator writes neither, because an .rbxmx carries both of those as binary
blobs (`Tags`, `AttributesSerialize`) that cannot be hand-written safely. So the
meshes arrived named `HouseFX_*`, which nothing in the engine reads, and sat
still. Nothing errored; there was no code to error.

THE SPEC IS A TABLE RATHER THAN A BLOB IN THE MODEL, which is the cheaper half
of the trade: it is diffable, it is one file for eighteen houses, and
`House.buildTemplateHouse` applies it while it is already walking the cloned
parts. What it costs is that a mesh renamed in Blender silently stops animating
-- so this prints every section that matched nothing, and that list is the thing
to read after an art drop.

THE KIND NAMES ARE THE ANIMATOR'S OWN. `pulse`, `cycle`, `chase`, `orbit`,
`bob` and `beacon` all have branches in `HouseFX.step`. `sway` does NOT: it is
emitted as authored and is INERT until somebody writes that branch, which is
better than mapping it onto `bob` and shipping an effect nobody asked for.
"""
import json
import sys
from collections import defaultdict
from pathlib import Path
from xml.etree import ElementTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import HOUSE_FOLDERS
import re as _re

ROOT = Path(__file__).resolve().parents[3]
TEMPLATES = ROOT / 'src/ReplicatedStorage/Shared/HouseTemplates'
# The kinds `HouseFX.step` has a branch for. `sway` and `scale` were inert
# until the branches were written; anything not here is reported as inert
# every run rather than quietly mapped onto a kind nobody asked for.
KNOWN = {'pulse', 'cycle', 'chase', 'orbit', 'bob', 'beacon', 'sway', 'scale'}


def parts_of(slug):
    path = TEMPLATES / f'{slug}.rbxmx'
    if not path.exists():
        return None
    root = ElementTree.parse(path).getroot()
    return [item.find('Properties').find("string[@name='Name']").text
            for item in root.iter('Item') if item.get('class') == 'MeshPart']


def styles_by_id():
    """id -> style, read out of `Config.HOUSE_TIERS` rather than assumed.

    THE TWO THAT DIFFER ARE THE TWO BIGGEST FX HOUSES. `neontower` is style
    `tower` and `skycastle` is style `castle`, and `House.buildTemplateHouse`
    looks this table up BY STYLE -- so a spec keyed by id handed the Neon Tower's
    twenty effects and the Sky Castle's seventeen to nobody, silently, which is
    exactly how they shipped with no lights.
    """
    text = (ROOT / 'src/ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf-8')
    start = text.index('Config.HOUSE_TIERS')
    end = text.index('Config.HOUSE_LEGACY_ORDER', start)
    out = {}
    for chunk in text[start:end].split('		id = "')[1:]:
        style = _re.search(r'style = "(\w+)"', chunk)
        if style:
            out[chunk.split('"')[0]] = style.group(1)
    return out


def hsv(rgb):
    """The mesh's authored colour as the animator wants it.

    EVERY COLOUR BRANCH IN `HouseFX.step` BUILDS ITS COLOUR FROM `Hue` AND `Sat`
    AND IGNORES THE PART'S OWN, and `Hue` defaults to 0 -- which is RED. So an
    effect emitted without these does not keep the artist's colour, it turns the
    part red: the Ice Palace's blue and the Thundercloud's were being overwritten
    every frame by a default nobody set.
    """
    r, g, b = (v / 255 for v in rgb)
    high, low = max(r, g, b), min(r, g, b)
    span = high - low
    if span == 0:
        hue = 0.0
    elif high == r:
        hue = ((g - b) / span % 6) / 6
    elif high == g:
        hue = ((b - r) / span + 2) / 6
    else:
        hue = ((r - g) / span + 4) / 6
    return round(hue, 4), round(0 if high == 0 else span / high, 4)


def main():
    by_folder = {v: k for k, v in HOUSE_FOLDERS.items()}
    styles = styles_by_id()
    spec, missing, inert = defaultdict(dict), [], set()

    for handoff in sorted((ROOT / 'assets/houses').glob('*/animation-handoff.json')):
        folder = handoff.parent.name
        name, _, _rev = folder.rpartition('-v')
        slug = by_folder.get(name, name)
        spec_file = json.loads(handoff.read_text(encoding='utf-8'))
        # TWO SHAPES, NOT ONE, AND READING ONLY THE FIRST LOST A WHOLE HOUSE.
        # Sixteen handoffs carry `effects`; the Gloop House carries `drips` --
        # same fields plus `phaseSeconds` in absolute seconds where `effects`
        # uses a 0..1 `phase`. Its three roof meshes were named `HouseFX_*` and
        # covered by nothing, which is the same silent gap as the id/style
        # mismatch: no error, no warning, an effect that simply never runs.
        effects = list(spec_file.get('effects') or [])
        for drip in spec_file.get('drips') or []:
            drip = dict(drip)
            drip['section'] = drip.get('section') or drip.get('object')
            period = float(drip.get('periodSeconds') or 0)
            if drip.get('phaseSeconds') is not None and period > 0:
                drip['phase'] = (float(drip['phaseSeconds']) / period) % 1
            # AUTHORED AS A SCALE, NOT A COLOUR. The block says "only scale
            # hanging goo, anchored at its top" and gives a `scaleZ` range --
            # and `HouseFX.step`'s `pulse` drives BRIGHTNESS. Emitting `pulse`
            # here would make the goo glow, which is an effect nobody asked
            # for; emitting the authored intent leaves it inert and REPORTED,
            # which is the same call `sway` already gets.
            drip['kind'] = 'scale'
            scale = drip.get('scaleZ')
            if isinstance(scale, list) and len(scale) > 1:
                drip['amount'] = float(scale[1])
            effects.append(drip)
        if not effects:
            continue
        colours = {m['name']: m['colorRGB'] for m in json.loads(
            (handoff.parent / 'roblox-import-report.json').read_text(encoding='utf-8'))['meshes']}
        parts = parts_of(slug)
        if parts is None:
            missing.append((slug, 'no template'))
            continue
        for effect in effects:
            section, kind = effect['section'], effect['kind']
            if kind not in KNOWN:
                inert.add(kind)
            hits = [p for p in parts if p == section or p.startswith(section + '_')]
            if not hits:
                missing.append((slug, section))
                continue
            # A PERIOD IS SECONDS AND `Rate` IS CYCLES A SECOND, which is the one
            # conversion here and the one that would be silently wrong: a 9-second
            # pulse written as Rate 9 is nine flashes a second, well past the
            # three-a-second accessibility ceiling `HouseFX.MAX_RATE` enforces.
            period = float(effect.get('periodSeconds') or 0)
            row = {'FX': kind, 'Phase': round(float(effect.get('phase') or 0), 4)}
            # A GLOW IS A MATERIAL, AND THE ART NEVER ASKS FOR ONE. Every mesh in
            # every manifest is authored flat -- the `*Glow` and `*Light`
            # materials are pale colours, not emission -- and the generator writes
            # SmoothPlastic on all of them. So a "glowing" house had its colours
            # animated on a matte surface, which at this exposure reads as almost
            # nothing: CLAUDE.md records that a PointLight is invisible here and
            # Neon is the only material that ignores the scene.
            #
            # ONLY THE LIGHT KINDS. `bob`, `orbit` and `sway` move a part and say
            # nothing about its surface, and Neon on a floating rock is the
            # "whole house glowed" mistake this generator's own comment records.
            #
            # SAFE ON COLOUR, MEASURED: all 65 light-effect meshes sit at or below
            # 0.70 relative luminance, so none is the pale Neon that renders as a
            # white hole. Anything added above that wants deepening first.
            if kind in {'pulse', 'cycle', 'chase', 'beacon'}:
                row['Neon'] = True
            if period > 0:
                row['Rate'] = round(1.0 / period, 4)
            # `intensity` is [low, high]; the animator's `Dim` is the floor a
            # cycle falls to, so the low end is exactly that number.
            intensity = effect.get('intensity')
            if isinstance(intensity, list) and intensity:
                row['Dim'] = round(float(intensity[0]), 4)
            if effect.get('amount') is not None:
                row['Amount'] = round(float(effect['amount']), 4)
            # A SWAY CARRIES ITS OWN AMPLITUDE AND HINGE AXIS. `Amount` is
            # degrees there rather than studs -- `HouseFX`'s sway branch is the
            # only reader, and it converts. The axis is named in BLENDER's frame
            # and the export maps (x, y, z) -> (-x, z, y), so Blender X is
            # Roblox X and Blender Y is Roblox Z; the sign does not matter for a
            # symmetric swing about that axis.
            if effect.get('amplitudeDegrees') is not None:
                row['Amount'] = round(float(effect['amplitudeDegrees']), 4)
                axis = {'X': (1, 0, 0), 'Y': (0, 0, 1), 'Z': (0, 1, 0)}.get(
                    str(effect.get('axisBlender') or 'Z').upper(), (0, 1, 0))
                row['AxisX'], row['AxisY'], row['AxisZ'] = axis
            for part in hits:
                shade = dict(row)
                rgb = colours.get(part) or colours.get(part.split('.')[0])
                if rgb:
                    shade['Hue'], shade['Sat'] = hsv(rgb)
                spec[styles.get(slug, slug)][part] = shade

    lines = [
        '--!strict',
        '-- GENERATED by assets/houses/tools/build_house_fx.py -- do not hand-edit.',
        '--',
        '-- What each authored effect mesh does, per house style. `HouseFX` finds its',
        '-- work through a CollectionService tag and reads these as ATTRIBUTES, and an',
        '-- .rbxmx cannot carry either without a binary blob -- so the template ships',
        '-- the geometry and `House.buildTemplateHouse` applies this while it is already',
        '-- walking the parts it cloned.',
        '--',
        '-- KEYED BY STYLE, like every other house table: `tower` is the Neon Tower and',
        '-- `castle` is the Sky Castle.',
        'local HouseFXSpec = {',
    ]
    for style in sorted(spec):
        lines.append('\t%s = {' % style)
        for part in sorted(spec[style]):
            row = spec[style][part]
            def render(key, value):
                if isinstance(value, bool):
                    return '%s = %s' % (key, 'true' if value else 'false')
                if isinstance(value, str):
                    return '%s = "%s"' % (key, value)
                return '%s = %s' % (key, value)
            fields = ', '.join(render(k, v) for k, v in row.items())
            lines.append('\t\t["%s"] = { %s },' % (part, fields))
        lines.append('\t},')
    lines += ['}', '', 'return HouseFXSpec', '']

    out = ROOT / 'src/ReplicatedStorage/Shared/HouseFXSpec.luau'
    out.write_text('\n'.join(lines), encoding='utf-8', newline='')

    total = sum(len(v) for v in spec.values())
    print('%d effect meshes across %d houses -> %s'
          % (total, len(spec), out.relative_to(ROOT)))
    for style in sorted(spec):
        print('  %-14s %d' % (style, len(spec[style])))
    if inert:
        print('\nINERT KINDS (authored, no branch in HouseFX.step): %s' % ', '.join(sorted(inert)))
    if missing:
        print('\nSECTIONS THAT MATCHED NO MESH -- these animate nothing:')
        for slug, section in missing:
            print('  %-14s %s' % (slug, section))
    return 0


if __name__ == '__main__':
    sys.exit(main())
