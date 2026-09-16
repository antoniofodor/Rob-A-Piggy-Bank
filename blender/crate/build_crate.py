"""Build the standalone Acorn storage asset; no game or Studio changes.
Run: /Applications/Blender.app/Contents/MacOS/Blender -b -t 4 --python blender/crate/build_crate.py
"""
import bpy
import json
import math
import struct
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/crate'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'NONE'
asset = bpy.data.collections.new('AcornStorageCrate')
scene.collection.children.link(asset)
palette = [
    (177, 113, 53), (192, 129, 65), (205, 144, 77), (184, 120, 57),
    (137, 82, 41), (151, 94, 46), (162, 101, 48), (119, 72, 37),
    (228, 175, 105), (218, 158, 84), (207, 148, 79), (239, 194, 127),
    (226, 180, 115), (102, 61, 33), (196, 142, 77), (164, 109, 56),
]
image = bpy.data.images.new('AcornStorageCrate_Atlas', width=512, height=512, alpha=True)
pixels = []
for y in range(512):
    for x in range(512):
        rgb = palette[(y // 128) * 4 + x // 128]
        pixels.extend([*(c / 255 for c in rgb), 1])
image.pixels.foreach_set(pixels)
image.filepath_raw = str(OUT / 'AcornStorageCrate_Atlas.png')
image.file_format = 'PNG'
image.save()
image.pack()
material = bpy.data.materials.new('AcornStorageCrate_Matte')
material.use_nodes = True
bsdf = material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = .9
bsdf.inputs['Metallic'].default_value = 0
tex = material.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image
tex.interpolation = 'Closest'
material.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
groups = {name: [] for name in ['CrateBody', 'CornerPosts', 'TopRim', 'AcornEmblem']}

def move_collection(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)

def colour(obj, tile, interior=None, bevel=8):
    mesh = obj.data
    mesh.materials.clear()
    mesh.materials.append(material)
    for layer in list(mesh.uv_layers):
        mesh.uv_layers.remove(layer)
    uv = mesh.uv_layers.new(name='Atlas')
    for poly in mesh.polygons:
        poly.use_smooth = False
        n = poly.normal
        swatch = tile
        if max(abs(v) for v in n) < .99:
            swatch = bevel
        elif interior is not None and n.dot(Vector(interior)) > .9:
            swatch = 6
        # Each face sits safely inside a solid atlas tile with generous padding.
        for k, li in enumerate(poly.loop_indices):
            a = 2 * math.pi * k / len(poly.loop_indices)
            uv.data[li].uv = ((swatch % 4 + .5 + .18 * math.cos(a)) / 4,
                              (swatch // 4 + .5 + .18 * math.sin(a)) / 4)

def box(name, centre, size, tile, group, bevel=.025, interior=None, skew=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    modifier = obj.modifiers.new('Small single-segment bevel', 'BEVEL')
    modifier.width = bevel
    modifier.segments = 1
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    if skew:
        for vertex in obj.data.vertices:
            vertex.co.z += skew * vertex.co.x / size[0]
        obj.data.update()
    colour(obj, tile, interior)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    move_collection(obj, asset)
    groups[group].append(obj)
    return obj

box('SolidFloor', (0, 0, .125), (3.26, 2.50, .25), 5, 'CrateBody', .02)
for side in [-1, 1]:
    for row, (z, height) in enumerate([(.465, .47), (.98, .49), (1.495, .48)]):
        box(f'WallY{side}_Plank{row+1}', (0, side * 1.235, z), (3.28, .18, height),
            [1, 2, 0][(row + (side == 1)) % 3], 'CrateBody', .021,
            interior=(0, -side, 0), skew=[.016, -.011, .008][row] * side)
        box(f'WallX{side}_Plank{row+1}', (side * 1.635, 0, z), (.18, 2.47, height),
            [2, 0, 3][row], 'CrateBody', .021, interior=(-side, 0, 0))
for x in [-1, 1]:
    for y in [-1, 1]:
        box(f'Corner_{x}_{y}', (x * 1.64, y * 1.24, .85), (.32, .32, 1.7),
            4 if x == y else 5, 'CornerPosts', .034)
for side in [-1, 1]:
    box(f'RimY{side}', (0, side * 1.255, 1.785), (3.6, .29, .23),
        2, 'TopRim', .024)
    box(f'RimX{side}', (side * 1.655, 0, 1.785), (.29, 2.22, .23),
        2, 'TopRim', .024)

def polygon_mesh(name, verts, faces, tile):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    asset.objects.link(obj)
    colour(obj, tile, bevel=tile)
    groups['AcornEmblem'].append(obj)
    return obj

# Thin octagonal badge bridges the wall seams; its graphic is flat geometry.
outline = [(-.29, -.37), (.29, -.37), (.37, -.29), (.37, .29),
           (.29, .37), (-.29, .37), (-.37, .29), (-.37, -.29)]
badge_vertices = [(x, y, 1.03 + z) for y in [-1.371, -1.316] for x, z in outline]
badge_faces = [tuple(range(8)), tuple(reversed(range(8, 16)))]
badge_faces += [(i, (i+1) % 8, (i+1) % 8 + 8, i+8) for i in range(8)]
polygon_mesh('BadgeBacking', badge_vertices, badge_faces, 9)

def graphic(name, points, tile, depth=-1.374):
    return polygon_mesh(name, [(x, depth, 1.03+z) for x, z in points],
                        [tuple(range(len(points)))], tile)

graphic('TanNut', [(-.19, .055), (-.185, -.065), (-.125, -.17), (0, -.25),
                   (.125, -.17), (.185, -.065), (.19, .055)], 12)
graphic('NutFacet', [(0, -.25), (.125, -.17), (.185, -.065), (.19, .055), (.085, .055)], 14, -1.375)
graphic('BrownCap', [(-.23, .045), (.23, .045), (.22, .12), (.13, .19),
                     (-.10, .19), (-.205, .125)], 13, -1.376)
graphic('BrownStem', [(-.025, .18), (.04, .18), (.085, .275), (.025, .285)], 13, -1.377)

objects = []
for name, parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    obj['part_role'] = name
    objects.append(obj)
root = bpy.data.objects.new('AcornStorageCrate', None)
asset.objects.link(root)
root.empty_display_type = 'PLAIN_AXES'
root.empty_display_size = .4
for obj in objects:
    obj.parent = root
    obj.data.calc_loop_triangles()
    assert tuple(obj.location) == (0, 0, 0)
    assert tuple(obj.scale) == (1, 1, 1)
triangles = {obj.name: len(obj.data.loop_triangles) for obj in objects}
total = sum(triangles.values())
coords = [v.co for obj in objects for v in obj.data.vertices]
mins = [min(v[i] for v in coords) for i in range(3)]
maxs = [max(v[i] for v in coords) for i in range(3)]
dimensions = [maxs[i] - mins[i] for i in range(3)]
assert total < 1000, total
assert all(abs(a-b) < 1e-5 for a,b in zip(dimensions, [3.6, 2.8, 1.9])), dimensions
assert abs(mins[2]) < 1e-6
root['dimensions_width_depth_height'] = dimensions
root['triangles'] = total
root['front'] = 'Blender -Y; glTF +Z'
root['pivot'] = 'Bottom centre; 1 Blender unit = 1 Roblox stud at import scale 1'

# Existing static exporter preserves per-face normals and embeds the PNG.
sys.path.insert(0, str(ROOT / 'blender/tree'))
from export_glb import export_glb
glb = OUT / 'AcornStorageCrate.glb'
export_glb(objects, OUT / 'AcornStorageCrate_Atlas.png', glb)
raw = glb.read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
doc['asset']['generator'] = 'AcornStorageCrate Blender static exporter'
doc['materials'][0]['name'] = material.name
doc['materials'][0]['pbrMetallicRoughness']['roughnessFactor'] = .9
doc['images'][0]['name'] = image.name
root_index = len(doc['nodes'])
doc['nodes'].append({'name': root.name, 'children': list(range(root_index))})
doc['scenes'][0] = {'name': root.name, 'nodes': [root_index]}
js = json.dumps(doc, separators=(',', ':')).encode()
js += b' ' * ((-len(js)) % 4)
binary = raw[20+length:]
glb.write_bytes(struct.pack('<4sII', b'glTF', 2, 20+len(js)+len(binary)) +
                struct.pack('<I4s', len(js), b'JSON') + js + binary)
report = {'name': root.name, 'triangles': triangles, 'total_triangles': total,
          'dimensions_blender_xyz': dimensions, 'bounds_min': mins, 'bounds_max': maxs,
          'dimensions_roblox_xyz': [dimensions[0], dimensions[2], dimensions[1]],
          'pivot': 'Bottom centre (0, 0, 0)', 'transforms_applied': True,
          'atlas': '512x512 sRGB flat colours; embedded in GLB and packed in blend',
          'front': 'Blender -Y / glTF +Z', 'material_count': 1,
          'glb_bytes': glb.stat().st_size}
(OUT / 'AcornStorageCrate-report.json').write_text(json.dumps(report, indent=2)+'\n')

# Presentation is separate and excluded from the GLB.
stage = bpy.data.collections.new('Presentation (not exported)')
scene.collection.children.link(stage)
def point(obj, at):
    obj.rotation_euler = (Vector(at)-obj.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.012))
ground = bpy.context.object
ground.name = 'PreviewGround'
move_collection(ground, stage)
ground_mat = bpy.data.materials.new('PreviewNeutral')
ground_mat.diffuse_color = (.115, .14, .16, 1)
ground.data.materials.append(ground_mat)
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 850
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.32, .37, .43, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .45
for name, loc, power, size in [('Key', (-3, -4, 7), 700, 5),
                              ('Fill', (5, -1, 4), 400, 4), ('Rim', (0, 4, 6), 600, 3)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.size = power, size
    obj = bpy.data.objects.new(name, data)
    stage.objects.link(obj)
    obj.location = loc
    point(obj, (0, 0, .7))
data = bpy.data.cameras.new('PreviewCamera')
camera = bpy.data.objects.new('PreviewCamera', data)
stage.objects.link(camera)
scene.camera = camera
data.type = 'ORTHO'
data.ortho_scale = 6.1
camera.location = (5, -7, 5.4)
point(camera, (0, 0, .8))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = objects[0]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_distance = 7
            area.spaces.active.region_3d.view_location = (0, 0, .8)
            area.spaces.active.shading.type = 'MATERIAL'
scene.render.filepath = str(OUT / 'AcornStorageCrate-preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'AcornStorageCrate.blend'))
bpy.ops.render.render(write_still=True)
print('CRATE_REPORT ' + json.dumps(report))
