#!/usr/bin/env python3
"""Turn a Studio dump of an imported house into its `studio-import.json`.

    python assets/houses/tools/record_house_import.py treehouse 2 dump.txt

The dump is one line per mesh, `name|meshid|sx,sy,sz|px,py,pz`, preceded by a
header carrying the model's own AABB. Every imported part has identity rotation
and `Size` equal to `MeshSize`, both checked when the dump is taken, which is
why neither is carried.

WHY THIS IS A SCRIPT AND NOT A NOTE. The file it writes is the seam between
Blender and the game: the runtime generator reads it for the mesh ASSET IDS and
the import's own frame, and it hard-fails when they disagree with the geometry
report. `groundY` in particular is derived rather than eyeballed -- it is the
imported Y that the authored z=0 plane lands on, so the house's feet sit on the
lawn rather than at the bottom of whatever roots dip below it.
"""
import json
import re
import sys
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug

ROOT = Path(__file__).resolve().parents[3]


def parse(text):
    lines = [l for l in text.strip().splitlines() if l.strip()]
    head = lines[0]
    lo = [float(v) for v in re.search(r'lo=([-\d.,e]+)', head).group(1).split(',')]
    hi = [float(v) for v in re.search(r'hi=([-\d.,e]+)', head).group(1).split(',')]
    bad = int(re.search(r'(?:bad|rotated)=(\d+)', head).group(1))
    if bad:
        raise SystemExit(f'the dump reports {bad} parts rotated or resized; '
                         'this recorder assumes neither')
    parts = []
    for line in lines[1:]:
        name, mesh, size, pos = line.split('|')
        parts.append({
            'name': name,
            'mesh': mesh if mesh.startswith('rbxassetid://') else 'rbxassetid://' + mesh,
            'meshSize': [float(v) for v in size.split(',')],
            'position': [float(v) for v in pos.split(',')],
        })
    return lo, hi, parts


def main():
    slug, revision, dump = sys.argv[1], sys.argv[2], sys.argv[3]
    out = ROOT / 'assets/houses' / f'{house_slug(slug)}-v{revision}'
    geometry = json.loads((out / 'geometry-report.json').read_text())
    lo, hi, parts = parse(Path(dump).read_text())

    # Studs per Blender unit, the inverse of whatever the importer applied.
    # Blender (x, y, z) maps to Roblox (-x, z, y), so authored DEPTH is the
    # imported Z and authored HEIGHT is the imported Y.
    authored = geometry['boundsBlender']['size']
    factors = [(hi[0] - lo[0]) / authored[0],
               (hi[1] - lo[1]) / authored[2],
               (hi[2] - lo[2]) / authored[1]]
    if max(factors) - min(factors) > 0.05:
        raise SystemExit(f'the import is not uniformly scaled: {factors}')
    per_unit = sum(factors) / 3

    # THE GROUND IS THE AUTHORED z=0 PLANE, NOT THE LOWEST PART IN THE IMPORT.
    # Roots, sunk stones and a bottom stair tread are all authored slightly
    # below zero, and seating the house off those lifts it off the lawn by
    # their own burial depth.
    ground = lo[1] - geometry['boundsBlender']['min'][2] * per_unit

    record = {
        'source': f'workspace/{slug}-roblox, imported from {house_slug(slug)}-roblox.fbx',
        'note': 'Dumped from Studio by assets/houses/tools/record_house_import.py. Every '
                'imported part carries identity rotation and Size equal to '
                'MeshSize, both checked at dump time, so only a position and '
                'the mesh size are needed.',
        'groundY': round(ground, 4),
        'bounds': {'lo': [round(v, 4) for v in lo], 'hi': [round(v, 4) for v in hi]},
        'parts': parts,
    }
    (out / 'studio-import.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'{slug}: {len(parts)} parts, {per_unit:.4f} imported units per stud, '
          f'groundY {ground:.2f}')
    print(f'wrote {(out / "studio-import.json").relative_to(ROOT)}')


if __name__ == '__main__':
    main()
