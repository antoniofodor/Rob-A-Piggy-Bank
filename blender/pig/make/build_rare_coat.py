"""Derive rare coats from the approved procedural graphs without changing parents.

Blender -b --python make/build_rare_coat.py -- --skin strawberrycow
Then bake_skin.py and package_animal.py --skin ID --name NAME.
"""
from pathlib import Path
import sys,json,hashlib
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import bpy,paths
from rare_coats import SPECS
args=sys.argv[sys.argv.index('--')+1:];key=args[args.index('--skin')+1];spec=SPECS[key]
source=Path(paths.skin_blend(spec['parent']));source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
def rgba(rgb):
    return tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)+(1,)
def labeled(nt,label):
    found=[n for n in nt.nodes if n.label==label]
    assert len(found)==1,(key,label,len(found))
    return found[0]
def paint(nt,label,side,color):
    node=labeled(nt,label)
    socket=node.inputs[side] if node.bl_idname=='ShaderNodeMixRGB' else [s for s in node.inputs if s.type=='RGBA'][side-1]
    socket.default_value=rgba(color)
def calc(nt,op,a,b,label):
    n=nt.nodes.new('ShaderNodeMath');n.operation=op;n.label=label
    if isinstance(a,(int,float)):n.inputs[0].default_value=a
    else:nt.links.new(a,n.inputs[0])
    if isinstance(b,(int,float)):n.inputs[1].default_value=b
    else:nt.links.new(b,n.inputs[1])
    return n.outputs[0]
def mix(nt,a,b,fac,label):
    n=nt.nodes.new('ShaderNodeMixRGB');n.label=label
    nt.links.new(a,n.inputs[1]);n.inputs[2].default_value=rgba(b);nt.links.new(fac,n.inputs[0]);return n.outputs[0]
materials={m for name in ('Body','Snout','Ears','Legs','Tail') for m in bpy.data.objects[name].data.materials if m}
for mat in materials:
    original_name=mat.name;mat.name=original_name.replace(spec['parent'],key)
    nt=mat.node_tree;bsdf=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    if not bsdf.inputs['Base Color'].is_linked:
        bsdf.inputs['Base Color'].default_value=rgba(spec['ear'] if 'ear' in original_name else spec['nose'])
        zero=nt.nodes.new('ShaderNodeValue');zero.label='RARE_EMISSIVE_MASK';zero.outputs[0].default_value=0
        continue
    parent=spec['parent']
    if parent=='cow':
        paint(nt,'white -> the muzzle pad',1,spec['base']);paint(nt,'white -> the muzzle pad',2,spec['nose'])
        paint(nt,'lay the blotches on',2,spec['ink'])
    elif parent=='tiger':
        paint(nt,'orange -> cream belly',1,spec['base']);paint(nt,'orange -> cream belly',2,spec['pale'])
        paint(nt,'nose pad back to orange',2,spec['nose']);paint(nt,'lay the ink on',2,spec['ink'])
        # Continue Glacier/Peppermint stripes to the separate solid snout.
        # The inherited angular and depth masks otherwise clear a bare collar
        # beneath it. Keep the parent scene and its common coat unchanged.
        for label in ('clean round the muzzle','clean muzzle'):
            mask=labeled(nt,label)
            mask.inputs['To Min'].default_value=1.0
            mask.inputs['To Max'].default_value=1.0
    elif parent=='leopard':
        paint(nt,'coat -> pale underside',1,spec['base']);paint(nt,'coat -> pale underside',2,spec['pale'])
        paint(nt,'the snout pad',2,spec['nose']);paint(nt,'the rosette centre',2,spec['fill']);paint(nt,'lay the petals on',2,spec['ink'])
    elif parent=='giraffe':
        paint(nt,'tan -> cream underside',1,spec['base']);paint(nt,'tan -> cream underside',2,spec['pale'])
        paint(nt,'the snout pad',2,spec['nose']);paint(nt,'lay the patches on',2,spec['ink'])
    elif parent=='ladybird':
        paint(nt,'red -> black',1,spec['base']);paint(nt,'red -> black',2,spec['ink'])
        paint(nt,'and the cheek patches on top',2,spec['pale'])
        # Keep the seed field; remove the insect's black head/wing seam.
        mark=labeled(nt,'BLACK HERE');nt.links.remove(mark.inputs[0].links[0]);mark.inputs[0].default_value=0
        belly=labeled(nt,'THE UNDERSIDE AND THE LEGS').outputs[0]
        color=bsdf.inputs['Base Color'].links[0].from_socket
        flesh=mix(nt,color,spec['pale'],belly,'hard watermelon flesh')
        seeds=labeled(nt,'THE SPOTS').outputs[0]
        color=mix(nt,flesh,spec['ink'],seeds,'black seeds over rind and flesh')
        nt.links.new(color,bsdf.inputs['Base Color'])
    # A sparse set of sugar/ice/honey highlights, confined to painted areas.
    # Kept as a separate grayscale map; color sheets remain opaque.
    tex=nt.nodes.new('ShaderNodeTexCoord')
    vor=nt.nodes.new('ShaderNodeTexVoronoi');vor.inputs['Scale'].default_value=6.5
    nt.links.new(tex.outputs['Object'],vor.inputs['Vector'])
    sparkle=calc(nt,'LESS_THAN',vor.outputs['Distance'],.19,'small rare highlight islands')
    sep=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(tex.outputs['Object'],sep.inputs[0])
    upper=calc(nt,'GREATER_THAN',sep.outputs['Z'],.12,'highlights above belly')
    behind=calc(nt,'GREATER_THAN',sep.outputs['Y'],-.72,'keep highlights off face')
    mask=calc(nt,'MULTIPLY',sparkle,calc(nt,'MULTIPLY',upper,behind,'back and shoulders'),'RARE_EMISSIVE_MASK')
    color=bsdf.inputs['Base Color'].links[0].from_socket
    # Visible little tonal highlights also read when emission is disabled.
    highlight=tuple(round(.65*c+.35*255) for c in spec['ink'])
    nt.links.new(mix(nt,color,highlight,mask,'rare accent colour'),bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value=.82
# A single muzzle colour also covers the dimple floors. Reusing the parent's
# full body field here leaves pale spots inside the nostrils (fixed on Tiger).
snout_mat=bpy.data.materials.new(key+'_snout');snout_mat.use_nodes=True
snout_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=rgba(spec['nose'])
snout_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
zero=snout_mat.node_tree.nodes.new('ShaderNodeValue');zero.label='RARE_EMISSIVE_MASK';zero.outputs[0].default_value=0
snout=bpy.data.objects['Snout']
for i in range(len(snout.data.materials)):snout.data.materials[i]=snout_mat
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=paths.skin_blend(key))
out=Path(paths.skin_dir(key));(out/'coat-spec.json').write_text(json.dumps(dict(spec,skin=key,rarity='rare',parentScene=str(source),parentSceneSha256=source_hash,emissiveStrength=.8,glow='Static sparse highlights; no animation or extra geometry'),indent=2))
# Bake a dedicated grayscale emissive map from the labeled source node.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=8;scene.render.bake.use_selected_to_active=False
import numpy as np
for group,names in [('body',['Body']),('trim',['Snout','Ears','Legs','Tail'])]:
    obs=[bpy.data.objects[n] for n in names];mats={m for ob in obs for m in ob.data.materials if m};saved=[]
    img=bpy.data.images.new(key+'_'+group+'_emissive',2048,2048,alpha=False);img.colorspace_settings.name='Non-Color'
    for mat in mats:
        nt=mat.node_tree;output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');saved.append((nt,output,output.inputs['Surface'].links[0].from_socket))
        emission=nt.nodes.new('ShaderNodeEmission');nt.links.new(labeled(nt,'RARE_EMISSIVE_MASK').outputs[0],emission.inputs['Color']);nt.links.new(emission.outputs[0],output.inputs['Surface'])
        target=nt.nodes.new('ShaderNodeTexImage');target.image=img;nt.nodes.active=target
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:ob.hide_render=False;ob.hide_set(False);ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.bake(type='EMIT')
    img.scale(1024,1024);img.filepath_raw=str(out/f'{key}_{group}_emissive.png');img.file_format='PNG';img.save()
    for nt,output,socket in saved:nt.links.new(socket,output.inputs['Surface'])
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash
print('RARE_COAT_AUTHORED',key,flush=True)
