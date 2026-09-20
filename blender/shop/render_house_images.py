"""Catalog images from the authored models used by HouseTemplates.

blender --background --python blender/shop/render_house_images.py [-- house-id ...]
Reads the walk-in sources without overwriting any blend or exported geometry.
"""
import bpy
import hashlib
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/shop-ui/house-images'
OUT.mkdir(parents=True, exist_ok=True)
rows = json.loads((ROOT / 'assets/houses/walk-in-manifest.json').read_text())['models']
selected = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
manifest = []
uploads_file = OUT / 'roblox-uploads.json'
uploads = json.loads(uploads_file.read_text()) if uploads_file.exists() else {}

for row in rows:
    if selected and row['id'] not in selected:
        continue
    source = ROOT / 'assets/houses' / row['blend']
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    # Presentation lights remain; the ground is not part of the house artwork.
    for obj in scene.objects:
        if obj.type == 'MESH' and obj.name.startswith('REVIEW_'):
            obj.hide_render = True
    visible = [o for o in scene.objects if o.type == 'MESH' and not o.hide_render]
    points = [o.matrix_world @ v.co for o in visible for v in o.data.vertices]
    assert points, row['id']
    camera = scene.camera
    direction = Vector((.65, -1.35, .70)).normalized()
    camera.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()
    rotation = camera.rotation_euler.to_matrix()
    projected = [rotation.transposed() @ p for p in points]
    lo = Vector(tuple(min(p[i] for p in projected) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in projected) for i in range(3)))
    center = rotation @ ((lo + hi) * .5)
    camera.data.type = 'ORTHO'
    # Blender's orthographic scale is the horizontal span for this landscape.
    camera.data.ortho_scale = max(hi.x - lo.x, (hi.y - lo.y) * 1.5) * 1.12
    camera.location = center + direction * max((hi - lo).length * 3, 100)
    camera.data.clip_end = 2000
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = 768
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    target = source.parent / 'shop-cards' / (row['id'] + '.png')
    target.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(target)
    bpy.ops.render.render(write_still=True)
    manifest.append({'id': row['id'], 'name': row['name'],
                     'source': str(source.relative_to(ROOT)).replace('\\', '/'),
                     'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                     'image': target.relative_to(ROOT).as_posix(),
                     'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    manifest[-1]['robloxAssetId'] = uploads.get(row['id'])
    target.with_suffix('.json').write_text(json.dumps(manifest[-1], indent=2) + '\n')
    print('HOUSE_IMAGE ' + row['id'], flush=True)

if not selected:
    (OUT / 'manifest.json').write_text(json.dumps({'size': [768, 512], 'houses': manifest}, indent=2) + '\n')
