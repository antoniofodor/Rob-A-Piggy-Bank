"""Render ride shop cards from the rides' own Roblox geometry.

blender --background --python blender/shop/render_ride_images.py
blender --background --python blender/shop/render_ride_images.py -- bmx,scooter

The source is assets/rides/ride-geometry.json: every BasePart of each
`RideModel.build(key)`, read back out of a live Studio session relative to the
model's own pivot (y 0 is the ground). A ride is nothing but Blocks, Cylinders
and Balls, so it is rebuilt here exactly rather than modelled a second time --
re-dump that file whenever RideModel changes, or the card shows the old ride.

Same studio, camera direction, size and framing as the guardian cards, so the
two shelves read as one set. A ride whose long axis runs along Roblox Z is
turned a quarter first, because the camera looks along that axis and would
otherwise see a skateboard end-on.

With a list after `--` only those rides render and their rows MERGE into the
manifest, for the reason the guardian script gives: a re-render of an uploaded
card is a new file whose hash no longer matches its asset.
"""
import bpy
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'blender/guards'))
from build_guards import material, studio, linear

geometry = json.loads((ROOT / 'assets/rides/ride-geometry.json').read_text())
config = (ROOT / 'src/ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf8')
rides = config.split('Config.RIDES = {', 1)[1].split('\n}', 1)[0]
catalogue = re.findall(r'^\t(\w+)\s*=\s*\{', rides, re.M)
names = {k: re.search(r'^\t' + k + r'\s*=\s*\{\s*name\s*=\s*"([^"]+)"', rides, re.M).group(1) for k in catalogue}
only = set(sys.argv[sys.argv.index('--')+1].split(',')) if '--' in sys.argv else None
assert not only or only <= set(catalogue), 'Unknown ride(s): %s' % sorted(only - set(catalogue))
assert set(catalogue) <= set(geometry), 'Rides with no geometry dump: %s' % sorted(set(catalogue) - set(geometry))

# Roblox is Y-up and Blender Z-up; (x, y, z) -> (x, -z, y) is a proper
# rotation, so it can sit in a matrix_world without mirroring anything.
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def ride_material(key, i, part):
    rgb, kind = tuple(part['c']), part['m']
    m = material('%s_%d' % (key, i), rgb)
    p = m.node_tree.nodes['Principled BSDF']
    if kind == 'Metal':
        p.inputs['Metallic'].default_value = .45
        p.inputs['Roughness'].default_value = .38
    elif kind == 'Neon':
        p.inputs['Emission Color'].default_value = (*[linear(v) for v in rgb], 1)
        p.inputs['Emission Strength'].default_value = 3.0
    else:
        p.inputs['Roughness'].default_value = .55
    if part['t'] > 0:
        p.inputs['Alpha'].default_value = 1 - part['t']
    return m


def primitive(part):
    """A unit mesh in the part's own Roblox frame, already at its size."""
    sx, sy, sz = part['s']
    if part['shape'] == 'Cylinder':
        # A Roblox cylinder's axis is its X; the circle takes the smaller of Y, Z.
        d = min(sy, sz)
        bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=d/2, depth=sx)
        o = bpy.context.object
        o.data.transform(Matrix.Rotation(math.pi/2, 4, 'Y'))
    elif part['shape'] == 'Ball':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=min(sx, sy, sz)/2)
        o = bpy.context.object
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.object
        o.data.transform(Matrix.Diagonal((sx, sy, sz, 1)))
    if part['shape'] != 'Block':
        for f in o.data.polygons:
            f.use_smooth = True
    return o


rows = []
for key in catalogue:
    if only and key not in only:
        continue
    parts = [p for p in geometry[key]['parts'] if p['t'] < 1]
    xs = [abs(p['cf'][0]) + max(p['s'])/2 for p in parts]
    zs = [abs(p['cf'][2]) + max(p['s'])/2 for p in parts]
    turn = Matrix.Rotation(math.pi/2, 4, 'Y') if max(zs) > max(xs) else Matrix.Identity(4)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new('World')
    camera = studio()
    bpy.data.objects['Studio_Floor'].hide_render = True
    points = []
    for i, part in enumerate(parts):
        c = part['cf']
        cf = Matrix(((c[3], c[4], c[5], c[0]), (c[6], c[7], c[8], c[1]), (c[9], c[10], c[11], c[2]), (0, 0, 0, 1)))
        o = primitive(part)
        o.name = '%s_%02d_%s' % (key, i, part['n'])
        o.data.materials.append(ride_material(key, i, part))
        o.matrix_world = TO_BLENDER @ turn @ cf
        bpy.context.view_layer.update()
        points.extend(o.matrix_world @ Vector(v) for v in o.bound_box)
    direction = Vector((.8, -1.4, .62)).normalized()
    camera.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()
    rotation = camera.rotation_euler.to_matrix()
    projected = [rotation.transposed() @ p for p in points]
    lo = Vector(tuple(min(p[i] for p in projected) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in projected) for i in range(3)))
    camera.location = rotation @ ((lo+hi)*.5) + direction*30
    camera.data.ortho_scale = max(hi.x-lo.x, (hi.y-lo.y)*1.5)*1.12
    scene.render.resolution_x, scene.render.resolution_y = 768, 512
    scene.cycles.samples = 48
    scene.render.film_transparent = True
    target = ROOT / 'assets/rides' / key / 'shop-cards' / (key+'.png')
    target.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(target)
    bpy.ops.render.render(write_still=True)
    rows.append(dict(id=key, name=names[key], parts=len(parts), turned=turn != Matrix.Identity(4),
                     source='assets/rides/ride-geometry.json',
                     sourceSha256=hashlib.sha256(json.dumps(geometry[key], sort_keys=True).encode()).hexdigest(),
                     image=target.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    print('RIDE_IMAGE '+key, flush=True)

out = ROOT / 'assets/shop-ui/ride-images'
out.mkdir(parents=True, exist_ok=True)
uploads_file = out / 'roblox-uploads.json'
uploads = json.loads(uploads_file.read_text()) if uploads_file.exists() else {}
for row in rows:
    row['robloxAssetId'] = uploads.get(row['id'])
    (ROOT / row['image']).with_suffix('.json').write_text(json.dumps(row, indent=2)+'\n')
manifest_file = out / 'manifest.json'
kept = {r['id']: r for r in json.loads(manifest_file.read_text())['rides']} if manifest_file.exists() else {}
kept.update({r['id']: r for r in rows})
missing = [key for key in catalogue if key not in kept]
assert not missing, 'Rides with no card: %s' % missing
manifest_file.write_text(json.dumps(dict(size=[768, 512], rides=[kept[k] for k in catalogue]), indent=2)+'\n')
