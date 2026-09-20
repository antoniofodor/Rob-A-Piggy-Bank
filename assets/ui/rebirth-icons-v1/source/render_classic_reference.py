"""Render the existing pig mesh in the configured Classic Pink colors. No mesh edits."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/pig/pig/pig_parts.blend'))
scene = bpy.context.scene

def srgb(values):
    def linear(v):
        v /= 255
        return v / 12.92 if v <= .04045 else ((v + .055)/1.055)**2.4
    return tuple(linear(v) for v in values) + (1,)

def material(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = srgb(rgb)
    bsdf.inputs['Roughness'].default_value = .38
    return mat

body = material('ClassicPink_UI', (244,168,194))
trim = material('ClassicTrim_UI', (214,122,148))
eye = material('ClassicEye_UI', (28,28,34))
visible = []
for ob in scene.objects:
    if ob.type != 'MESH' or ob.name.startswith('Fur_') or ob.name == 'NostrilPreview':
        ob.hide_render = True
        continue
    ob.hide_render = False
    mat = body if ob.name == 'Body' else eye if ob.name in ('EyePreview','NostrilPreview') else trim
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    visible.append(ob)

def aim(ob, target):
    ob.rotation_euler = (Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()

world = bpy.data.worlds.new('UI_Studio')
scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (1,1,1,1)
world.node_tree.nodes['Background'].inputs[1].default_value = .65
for name, loc, energy, size in [('Key',(-4,-5,6),450,5),('Fill',(4,-3,2),220,5),('Rim',(2,4,5),350,4)]:
    ld = bpy.data.lights.new(name,'AREA'); ld.energy=energy; ld.size=size
    ob = bpy.data.objects.new(name,ld);scene.collection.objects.link(ob);ob.location=loc;aim(ob,(0,0,0))
cam_data=bpy.data.cameras.new('UI_Camera');cam_data.type='ORTHO';cam_data.ortho_scale=3.5
cam=bpy.data.objects.new('UI_Camera',cam_data);scene.collection.objects.link(cam)
cam.location=(-4.4,-6.2,2.6);aim(cam,(0,-.04,.10));scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
(OUT/'references').mkdir(parents=True,exist_ok=True)
scene.render.filepath=str(OUT/'references/classic-piggy-model.png')
bpy.ops.render.render(write_still=True)
