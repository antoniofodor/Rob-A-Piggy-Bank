"""Build the untextured two-part lasso. Run with Blender --background --python."""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1]
for folder in ('parts', 'preview'):
    (OUT / folder).mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, rgb):
    linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in [c / 255 for c in rgb]]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Roughness'].default_value = .82
    return mat

tan = material('Rope_LightTan', (218, 181, 126))
brown = material('Grip_DarkBrown', (91, 51, 30))

# A single continuous spiral, four passes across the sides. Its inner end
# terminates inside the leather keeper; the outer end bends into a straight tail.
points = []
steps = 224
for i in range(steps + 1):
    t = i / steps
    angle = math.pi / 2 + 7 * math.pi * t
    r = .43 + .665 * t
    points.append(Vector((r * math.cos(angle), 0, r * math.sin(angle))))

def bezier(a, b, c, d, t):
    return a * (1-t)**3 + b * (3*(1-t)**2*t) + c * (3*(1-t)*t*t) + d * t**3

start = points[-1]
for i in range(1, 13):
    points.append(bezier(start, start + Vector((.27, 0, -.008)), Vector((.32, 0, -1.17)), Vector((.32, 0, -1.36)), i/12))
points.extend([Vector((.32, 0, -1.48)), Vector((.32, 0, -1.63))])

radius = .088
sides = 10
verts, faces = [], []
for i, p in enumerate(points):
    tangent = (points[min(i+1, len(points)-1)] - points[max(0, i-1)]).normalized()
    n = Vector((0, -1, 0))
    b = tangent.cross(n).normalized()
    for j in range(sides):
        a = 2 * math.pi * j / sides
        verts.append(tuple(p + radius * (math.cos(a) * n + math.sin(a) * b)))
for i in range(len(points)-1):
    for j in range(sides):
        faces.append((i*sides+j, i*sides+(j+1)%sides, (i+1)*sides+(j+1)%sides, (i+1)*sides+j))
faces += [tuple(reversed(range(sides))), tuple((len(points)-1)*sides+j for j in range(sides))]
mesh = bpy.data.meshes.new('RopeGeometry')
mesh.from_pydata(verts, [], faces)
mesh.update()
rope = bpy.data.objects.new('Rope', mesh)
bpy.context.collection.objects.link(rope)
rope.data.materials.append(tan)

# A broad leather keeper enclosing every upper turn, with rounded corners.
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, .715))
grip = bpy.context.object
grip.name = 'Grip'
grip.dimensions = (.37, .255, .81)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bevel = grip.modifiers.new('Rounded leather edges', 'BEVEL')
bevel.width = .07
bevel.segments = 3
bpy.ops.object.modifier_apply(modifier=bevel.name)
grip.data.materials.append(brown)
parts = [rope, grip]

# Put both origins at the assembled bounds center, preserving registration.
all_world = [obj.matrix_world @ v.co for obj in parts for v in obj.data.vertices]
low = Vector(tuple(min(p[k] for p in all_world) for k in range(3)))
high = Vector(tuple(max(p[k] for p in all_world) for k in range(3)))
center = (low + high) / 2
for obj in parts:
    for v in obj.data.vertices:
        v.co = obj.matrix_world @ v.co - center
    obj.location = (0, 0, 0)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for poly in obj.data.polygons:
        poly.use_smooth = False

def select(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

def export(path, objs):
    select(objs)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={'MESH'},
        axis_forward='-Z', axis_up='Y', apply_unit_scale=True, bake_space_transform=True,
        use_mesh_modifiers=True, mesh_smooth_type='FACE', add_leaf_bones=False, bake_anim=False)

export(OUT / 'lasso-rope.fbx', parts)
for obj in parts:
    export(OUT / 'parts' / f'{obj.name.lower()}.fbx', [obj])

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.world.color = (.20, .20, .20)
scene.view_settings.view_transform = 'Standard'

def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()

for name, pos, power, size in [('Key', (-3,-4,5), 430, 4), ('Fill', (4,-2,1), 160, 3), ('Rim', (0,3,4), 260, 3)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = size
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = pos
    aim(light, (0,0,0))
bpy.ops.object.camera_add(location=(.65, -7, .5))
camera = bpy.context.object
camera.name = 'PreviewCamera'
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.35
aim(camera, (0,0,0))
scene.camera = camera

report = {'asset': 'rope', 'status': 'local source and exports; not uploaded',
    'parts': [], 'textures': 0, 'shading': 'flat', 'turns': 3.5,
    'dimensions_blender': list(high-low), 'pivot': 'assembled bounds center',
    'grip_center_blender': list(Vector((0,0,.715))-center),
    'export_axes': {'up': 'Y', 'forward': '-Z'},
    'colors_srgb': {'Rope': [218,181,126], 'Grip': [91,51,30]}}
for obj in parts:
    obj.data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    record = {'name': obj.name, 'vertices': len(obj.data.vertices),
        'triangles': len(obj.data.loop_triangles),
        'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
        'flat_shaded': all(not p.use_smooth for p in obj.data.polygons)}
    bm.free()
    assert record['non_manifold_edges'] == 0, record
    assert record['triangles'] < 10000, record
    report['parts'].append(record)
(OUT / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
select(parts)
# Make the source open in a useful material-color view.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.shading.color_type = 'MATERIAL'
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'lasso-rope.blend'))
scene.render.filepath = str(OUT / 'preview' / 'lasso-rope-hero.png')
bpy.ops.render.render(write_still=True)
camera.location = (0,-7,0)
aim(camera, (0,0,0))
scene.render.filepath = str(OUT / 'preview' / 'lasso-rope-front.png')
bpy.ops.render.render(write_still=True)
print(json.dumps(report, indent=2))
