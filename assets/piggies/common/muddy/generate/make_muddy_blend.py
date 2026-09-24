"""Author Muddy's approved splash coat in 3D, preserving shared meshes and UVs.

Blender -b --python assets/piggies/common/muddy/generate/make_muddy_blend.py
Then bake_skin.py -- --skin muddy; package_animal.py -- --skin muddy --name "Muddy Piggy".
"""
from pathlib import Path
import hashlib
import json
import math
import random
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'blender/pig'))
import paths
from skin_colours import skin

HOME = Path(paths.skin_dir('muddy'))
for room in ('source', 'sheets', 'preview', 'package'):
    (HOME / room).mkdir(exist_ok=True)
CORE = ('Body', 'Snout', 'Ears', 'Legs', 'Tail', 'EyePreview')
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'Muddy Piggy - approved splash coat'
source = Path(paths.skin_closed_blend('cow'))
with bpy.data.libraries.load(str(source), link=False) as (available, loaded):
    loaded.objects = list(CORE)
parts = dict(zip(CORE, loaded.objects))
assert all(parts.values())
for name, ob in parts.items():
    scene.collection.objects.link(ob)
    ob.name = name
    ob.hide_render = False
    ob.hide_viewport = False
    ob.hide_set(False)
    for mod in list(ob.modifiers):
        ob.modifiers.remove(mod)

def signature(ob):
    return hashlib.sha256(json.dumps({
        'vertices': [list(v.co) for v in ob.data.vertices],
        'faces': [list(p.vertices) for p in ob.data.polygons],
        'uvs': [[list(p.uv) for p in uv.data] for uv in ob.data.uv_layers],
    }).encode()).hexdigest()

before = {name: signature(ob) for name, ob in parts.items()}
PINK, TRIM = skin('muddy')
MUD = (112/255, 74/255, 48/255)
MUD_LIGHT = (139/255, 95/255, 63/255)

def rgba(rgb):
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb) + (1,)

def material(name, base, mode='clean'):
    m = bpy.data.materials.new('Muddy_' + name)
    m.use_nodes = True
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = rgba(base)
    bsdf.inputs['Roughness'].default_value = .72
    bsdf.inputs['Specular IOR Level'].default_value = .18
    m.diffuse_color = rgba(base)
    if mode == 'clean':
        return m
    tex = nodes.new('ShaderNodeTexCoord')
    xyz = nodes.new('ShaderNodeSeparateXYZ')
    links.new(tex.outputs['Object'], xyz.inputs[0])
    x, y, z = [xyz.outputs[k] for k in 'XYZ']
    def calc(op, a, b=0):
        n = nodes.new('ShaderNodeMath'); n.operation = op
        for i, value in enumerate((a,b)):
            if isinstance(value, (int,float)): n.inputs[i].default_value = value
            else: links.new(value, n.inputs[i])
        return n.outputs[0]
    def noise(scale, detail=1):
        n = nodes.new('ShaderNodeTexNoise')
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = .4
        links.new(tex.outputs['Object'], n.inputs['Vector'])
        return n.outputs['Fac']
    coast = calc('MULTIPLY', calc('SUBTRACT', noise(8), .5), .72)
    fine = calc('MULTIPLY', calc('SUBTRACT', noise(24), .5), .05)
    edge = calc('ADD', coast, fine)
    if mode == 'legs':
        mask = calc('LESS_THAN', z, calc('ADD', -.82, edge))
        # Smaller splashes above the solid wet feet, with variable size.
        vor = nodes.new('ShaderNodeTexVoronoi')
        vor.inputs['Scale'].default_value = 24
        links.new(tex.outputs['Object'], vor.inputs['Vector'])
        dots = calc('LESS_THAN', vor.outputs['Distance'], calc('MULTIPLY', noise(13), .3))
        dots = calc('MULTIPLY', dots, calc('LESS_THAN', z, -.64))
        mask = calc('MAXIMUM', mask, dots)
    else:
        # Lower flank splashes join the belly, with a clear pink face.
        low = calc('LESS_THAN', z, calc('ADD', -.39, edge))
        low = calc('MULTIPLY', low, calc('GREATER_THAN', y, -.58))
        # One connected patch over the rear crown, with dripping scalloped edges.
        back = calc('GREATER_THAN', calc('ADD', z, calc('MULTIPLY', y, .68)), calc('ADD', .87, edge))
        back = calc('MULTIPLY', back, calc('GREATER_THAN', y, -.06))
        mask = calc('MAXIMUM', low, back)
        def splat(center, radii):
            d = 0
            for axis, c, r in zip((x,y,z), center, radii):
                q = calc('DIVIDE', calc('SUBTRACT', axis,c),r)
                d = calc('ADD', d, calc('MULTIPLY',q,q))
            return calc('LESS_THAN',d,calc('ADD',1,calc('MULTIPLY',edge,.75)))
        # Upward fingers along the flanks; asymmetric and attached to the mud below.
        for c,r in [((-0.86,-.1,-.35),(.22,.19,.30)),
                    ((-.70,.49,-.31),(.25,.23,.37)),
                    ((.87,.02,-.34),(.23,.17,.31)),
                    ((.68,.57,-.25),(.26,.22,.36))]:
            mask = calc('MAXIMUM',mask,splat(c,r))
        rng = random.Random(70923)
        # Irregularly placed droplets between the two main mud regions.
        body = parts['Body']
        for i in range(90):
            if i < 54:
                direction = Vector((rng.choice((-1,1)),rng.uniform(-.5,.9),rng.uniform(-.4,.32))).normalized()
            else:
                direction = Vector((rng.uniform(-1,1),rng.uniform(-.48,1),rng.uniform(-.45,.85))).normalized()
            hit, p, normal, face = body.ray_cast(direction*4,-direction)
            if not hit or p.y < -.3 or (p.y < .05 and p.z > .20):
                continue
            r = rng.uniform(.013,.036)
            mask = calc('MAXIMUM',mask,splat(p,(r,r,r*rng.uniform(1.2,2.2))))
    # Broad, restrained two-tone variation reads as wet and drying earth.
    mud = nodes.new('ShaderNodeMixRGB')
    mud.inputs[1].default_value = rgba(MUD)
    mud.inputs[2].default_value = rgba(MUD_LIGHT)
    links.new(noise(9), mud.inputs[0])
    mix = nodes.new('ShaderNodeMixRGB')
    mix.inputs[1].default_value = rgba(base)
    links.new(mask,mix.inputs[0]); links.new(mud.outputs[0],mix.inputs[2])
    links.new(mix.outputs[0],bsdf.inputs['Base Color'])
    return m

def assign(ob, m):
    ob.data.materials.clear(); ob.data.materials.append(m)
    for p in ob.data.polygons: p.material_index = 0

assign(parts['Body'],material('Body',PINK,'body'))
assign(parts['Legs'],material('Leg_splashes',PINK,'legs'))
assign(parts['Snout'],material('Snout',TRIM))
assign(parts['Tail'],material('Tail',PINK))
ears = parts['Ears']
for i in range(len(ears.data.materials)):
    ears.data.materials[i] = material('Ear_'+str(i), PINK if i == 0 else TRIM)
assign(parts['EyePreview'],material('Eyes',(38/255,30/255,34/255)))
assert before == {name:signature(ob) for name,ob in parts.items()}
scene['skinKey'] = 'muddy'
scene['design'] = 'Approved muddy-concept-v1: leg splashes, lower flanks, back and rump; clean face.'
scene.view_settings.view_transform = 'Standard'
bpy.ops.wm.save_as_mainfile(filepath=str(HOME/'source/muddy.blend'))
(HOME/'generate/geometry-check.json').write_text(json.dumps({
    'source':str(source.relative_to(ROOT)), 'geometryAndUVPreserved':True,
    'partSignatures': before, 'addedVertices':0, 'addedTriangles':0,
},indent=2)+'\n')
print('MUDDY SOURCE SAVED; geometry and UVs unchanged',flush=True)
