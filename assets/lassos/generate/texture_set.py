"""UV the shared coil and effect meshes; render and save four tier looks."""
from pathlib import Path
import sys
import json
import math
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_set as kit

ROOT = kit.ROOT
TIERS = ['rope','braided','golden','elite']
for folder in ['coil','tiers','tiers/preview','coil/parts']:
    (ROOT/folder).mkdir(exist_ok=True)

def uv_layer(obj):
    while obj.data.uv_layers:
        obj.data.uv_layers.remove(obj.data.uv_layers[0])
    return obj.data.uv_layers.new(name='TierUV').data

def uv_coil(obj):
    uv = uv_layer(obj)
    centers = [sum((obj.data.vertices[i+j].co for j in range(10)),Vector())/10
               for i in range(0,len(obj.data.vertices),10)]
    distance = [0.0]
    for a,b in zip(centers,centers[1:]):
        distance.append(distance[-1]+(b-a).length)
    for face in obj.data.polygons:
        sides = [obj.data.loops[i].vertex_index%10 for i in face.loop_indices]
        seam = 0 in sides and 9 in sides
        for li in face.loop_indices:
            vid = obj.data.loops[li].vertex_index
            ring,side = divmod(vid,10)
            if seam and side == 0: side = 10
            uv[li].uv = (distance[ring]/.6, .03+.57*side/10)

def uv_grip(obj):
    uv = uv_layer(obj)
    lo,hi = kit.bounds([obj])
    for face in obj.data.polygons:
        front = face.normal.y < -.45
        u0 = .03 if front else .53
        for li in face.loop_indices:
            v = obj.data.vertices[obj.data.loops[li].vertex_index].co
            if abs(face.normal.z) > .75:
                a = (v.x-lo.x)/(hi.x-lo.x)
                b = (v.y-lo.y)/(hi.y-lo.y)
            elif abs(face.normal.x) > .75:
                a = (v.y-lo.y)/(hi.y-lo.y)
                b = (v.z-lo.z)/(hi.z-lo.z)
            else:
                a = (v.x-lo.x)/(hi.x-lo.x)
                b = (v.z-lo.z)/(hi.z-lo.z)
            uv[li].uv = (u0+.44*a,.66+.30*b)

def uv_effect(obj,key):
    uv = uv_layer(obj)
    for face in obj.data.polygons:
        values = []
        for li in face.loop_indices:
            v = obj.data.vertices[obj.data.loops[li].vertex_index].co
            if key == 'loop':
                index = obj.data.loops[li].vertex_index
                if index < 480:
                    a = math.atan2(v.y,v.x)%(2*math.pi)
                    c = math.atan2(v.z,math.hypot(v.x,v.y)-.84)%(2*math.pi)
                    values.append([li,a*.84/.6,c/(2*math.pi)])
                else:
                    values.append([li,v.x/.6,(math.atan2(v.z,v.y)%(2*math.pi))/(2*math.pi)])
            else:
                values.append([li,v.x/.6,(math.atan2(v.z,v.y)%(2*math.pi))/(2*math.pi)])
        # Avoid crossing the entire texture around a cylindrical seam.
        if key == 'loop' and all(obj.data.loops[x[0]].vertex_index < 480 for x in values):
            period = 2*math.pi*.84/.6
            if max(x[1] for x in values)-min(x[1] for x in values) > period/2:
                for row in values:
                    if row[1] < period/2: row[1] += period
        if max(x[2] for x in values)-min(x[2] for x in values) > .5:
            for row in values:
                if row[2] < .5: row[2] += 1
        # Clamp the repeated circumference back into the padded rope strip.
        # For a seam face, map the seam vertex to its upper boundary.
        for li,u,v in values:
            uv[li].uv = (u,.03+.57*min(v,1))

def texture_material(tier):
    m = bpy.data.materials.new('Tier_'+tier)
    m.diffuse_color = (1,1,1,1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = .75
    image = bpy.data.images.load(str(ROOT/'textures'/f'{tier}.png'),check_existing=True)
    image.colorspace_settings.name = 'sRGB'
    image.pack()
    node = m.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    node.extension = 'REPEAT'
    node.interpolation = 'Linear'
    m.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color'])
    return m

def use_material(objs,m):
    for obj in objs:
        obj.data.materials.clear()
        obj.data.materials.append(m)
        for face in obj.data.polygons:
            face.material_index = 0

def save_export(path,objs):
    kit.select(objs)
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},
        axis_forward='-Z',axis_up='Y',apply_unit_scale=True,bake_space_transform=True,
        use_mesh_modifiers=True,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,
        path_mode='RELATIVE',embed_textures=False)

bpy.ops.wm.open_mainfile(filepath=str(ROOT/'rope'/'lasso-rope.blend'))
bpy.context.preferences.filepaths.save_version = 0
rope,grip = bpy.data.objects['Rope'],bpy.data.objects['Grip']
uv_coil(rope); uv_grip(grip)
objs = [rope,grip]
scene = bpy.context.scene
scene.render.resolution_x = scene.render.resolution_y = 900
scene.cycles.samples = 40
scene.camera.location = (.65,-7,.5)
kit.aim(scene.camera)
for tier in TIERS:
    use_material(objs,texture_material(tier))
    kit.select(objs)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tiers'/f'{tier}.blend'))
    if tier == 'rope':
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'coil'/'coil.blend'))
        save_export(ROOT/'coil'/'coil.fbx',objs)
        for obj in objs:
            save_export(ROOT/'coil'/'parts'/f'{obj.name.lower()}.fbx',[obj])
    scene.render.filepath = str(ROOT/'tiers'/'preview'/f'{tier}.png')
    bpy.ops.render.render(write_still=True)
    print('TIER_COMPLETE '+tier,flush=True)
source = json.loads((ROOT/'rope'/'manifest.json').read_text())
source.update({'asset':'coil','files':{'blend':'coil.blend','fbx':'coil.fbx'},
    'tiers':TIERS,'textures':1,'texture_source':'../textures/{tier}.png',
    'material_color':[255,255,255],
    'notes':['Identical mesh geometry across all four tiers; Elite is a texture variant.',
             'Both parts use the same atlas. Change both TextureIDs/ColorMaps together.',
             'Texture U repeats along the rope; do not clamp UVs to 0..1.',
             'The untextured source remains in ../rope/.']})
(ROOT/'coil'/'manifest.json').write_text(json.dumps(source,indent=2)+'\n')

# The same atlases also work on the two rope effect models.
for key,name in [('loop','Loop'),('snapped-end','SnappedEnd')]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/key/(key+'.blend')))
    bpy.context.preferences.filepaths.save_version = 0
    obj = bpy.data.objects[name]
    uv_effect(obj,key)
    for tier in TIERS:
        use_material([obj],texture_material(tier))
        if tier == 'rope':
            bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/key/(key+'.blend')))
            save_export(ROOT/key/(key+'.fbx'),[obj])
            save_export(ROOT/key/'parts'/(name.lower()+'.fbx'),[obj])
        bpy.context.scene.render.filepath = str(ROOT/key/'preview'/f'{key}-{tier}.png')
        bpy.ops.render.render(write_still=True)
    report = json.loads((ROOT/key/'manifest.json').read_text())
    report.update({'textures':1,'tiers':TIERS,'texture_source':'../textures/{tier}.png',
                   'material_color':[255,255,255]})
    (ROOT/key/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('TEXTURES_COMPLETE',flush=True)
