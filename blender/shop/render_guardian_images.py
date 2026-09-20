"""Render guardian cards beside the original rigs; never save over source blends.

blender --background --python blender/shop/render_guardian_images.py
blender --background --python blender/shop/render_guardian_images.py -- terrier,mastiff
Colors mirror GuardRig.tones, using Config coats and authored creature palettes.

With a comma-separated list after `--`, only those coats render and their rows
MERGE into the manifest. Without it every coat renders. The partial form exists
so adding a coat does not re-render the ones already uploaded: a fresh render
of an uploaded card is a new file whose hash no longer matches the asset its
row points at.
"""
import bpy
import hashlib
import json
import re
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'blender/guards'))
from build_guards import material, studio

text = (ROOT / 'src/ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf8')
coats = text.split('Config.DOG_COATS = {', 1)[1].split('\n}', 1)[0]
only = set(sys.argv[sys.argv.index('--')+1].split(',')) if '--' in sys.argv else None
catalogue = [key for key, _ in re.findall(r'\b(\w+)\s*=\s*\{(.*?)\n\s*}', coats, re.S)]
assert not only or only <= set(catalogue), 'Unknown coat(s): %s' % sorted(only - set(catalogue))
rows = []
for key, body in re.findall(r'\b(\w+)\s*=\s*\{(.*?)\n\s*}', coats, re.S):
    if only and key not in only:
        continue
    name = re.search(r'name\s*=\s*"([^"]+)"', body).group(1)
    rig = re.search(r'guardModel\s*=\s*"([^"]+)"', body)
    rig = rig.group(1) if rig else 'shepherd'
    source = ROOT / f'assets/guards/{rig}/{rig}.blend'
    report = json.loads(source.with_name(rig+'-report.json').read_text())
    tones = {k: tuple(v) if v else None for k,v in report['palette'].items()}
    if rig == 'shepherd':
        for dst, src in [('fur', 'fur'), ('dark', 'furDark'), ('collar', 'collar')]:
            tones[dst] = tuple(map(int, re.search(src + r'\s*=\s*Color3.fromRGB\(([^)]+)\)', body).group(1).split(',')))
        tones['light'] = tuple(v + (255-v)*.35 for v in tones['fur'])
    tones.update(brow=tones['fur'], mask=tuple(a*.6+b*.4 for a,b in zip(tones['fur'], tones['light'])),
                 eye=(18,18,20), nose=(29,27,30), mouth=(41,24,31), teeth=(248,232,189),
                 inner=(201,126,112), armor=(131,48,78), accent=(238,122,64), silver=(171,170,182))
    tones['collar'] = tones['collar'] or (223,177,44)
    tones = {k: v for k,v in tones.items() if isinstance(v, tuple)}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new('World')
    camera = studio()
    bpy.data.objects['Studio_Floor'].hide_render = True
    names = set(report['parts']) | {rig+'_Rig'}
    with bpy.data.libraries.load(str(source), link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in names]
    mats = {tone: material(key+'_'+tone, rgb) for tone,rgb in tones.items()}
    for obj in dst.objects:
        scene.collection.objects.link(obj)
        if obj.type == 'MESH':
            obj.data.materials.clear()
            obj.data.materials.append(mats[report['parts'][obj.name]['tone']])
    scene.frame_set(1)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in dst.objects:
        if obj.type == 'MESH':
            evaluated = obj.evaluated_get(deps)
            points.extend(evaluated.matrix_world @ Vector(p) for p in evaluated.bound_box)
    direction = Vector((.8, -1.4, .62)).normalized()
    camera.rotation_euler = (-direction).to_track_quat('-Z','Y').to_euler()
    rotation = camera.rotation_euler.to_matrix()
    projected = [rotation.transposed() @ p for p in points]
    lo = Vector(tuple(min(p[i] for p in projected) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in projected) for i in range(3)))
    camera.location = rotation @ ((lo+hi)*.5) + direction*30
    camera.data.ortho_scale = max(hi.x-lo.x, (hi.y-lo.y)*1.5)*1.12
    scene.render.resolution_x, scene.render.resolution_y = 768, 512
    scene.cycles.samples = 48
    scene.render.film_transparent = True
    target = source.parent / 'shop-cards' / (key+'.png')
    target.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(target)
    bpy.ops.render.render(write_still=True)
    rows.append(dict(id=key, name=name, rig=rig, source=source.relative_to(ROOT).as_posix(),
                     sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                     image=target.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                     tones=tones))
    print('GUARDIAN_IMAGE '+key, flush=True)
out = ROOT / 'assets/shop-ui/guardian-images'
out.mkdir(parents=True, exist_ok=True)
uploads_file = out / 'roblox-uploads.json'
uploads = json.loads(uploads_file.read_text()) if uploads_file.exists() else {}
for row in rows:
    row['robloxAssetId'] = uploads.get(row['id'])
    (ROOT / row['image']).with_suffix('.json').write_text(json.dumps(row, indent=2)+'\n')
# MERGED, NOT REPLACED, so a partial run keeps every row it did not render --
# and ordered by the catalogue, so the manifest reads in the shop's own order.
manifest_file = out / 'manifest.json'
kept = {r['id']: r for r in json.loads(manifest_file.read_text())['guardians']} if manifest_file.exists() else {}
kept.update({r['id']: r for r in rows})
# EVERY COAT HAS A CARD. This replaced `assert len(rows) == 9`, which was the
# catalogue's size on the day it was written: the first coat added after it
# would have failed a full run with nothing wrong, and a partial run could not
# have passed it at all.
missing = [key for key in catalogue if key not in kept]
assert not missing, 'Coats with no card: %s' % missing
manifest_file.write_text(json.dumps(dict(size=[768,512], guardians=[kept[k] for k in catalogue]), indent=2)+'\n')
