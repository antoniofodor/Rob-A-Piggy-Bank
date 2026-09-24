"""Check a reference art model; export single-colour FBX and draft mounts.

Usage: Blender --background --python this_file.py -- slime 2
"""
import bpy,json,sys,math,xml.etree.ElementTree as E
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
from mathutils import Vector
from mathutils.bvhtree import BVHTree

slug,revision=sys.argv[sys.argv.index('--')+1:]
out=Path(__file__).resolve().parents[3]/'assets/houses'/f'{house_slug(slug)}-v{revision}'
r=json.loads((out/'geometry-report.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(out/f'{house_slug(slug)}.blend'))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('REVIEW')]
assert len(objects)==r['visualMeshes'],(len(objects),r['visualMeshes'])
bpy.context.view_layer.update()
trees=[(o.name,BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons])) for o in objects]
blocked=[];samples=0
for route in r.get('routesBlender',[]):
    for p,q in zip(route['points'],route['points'][1:]):
        p,q=Vector(p),Vector(q);steps=max(1,math.ceil((q-p).length/.5))
        for i in range(steps+1):
            point=p.lerp(q,i/steps);foot=0
            for name,tree in trees:
                hit,_,_,_=tree.ray_cast(Vector((point.x,point.y,1.8)),Vector((0,0,-1)),2)
                if hit is not None and -.1<=hit.z<1.3:foot=max(foot,hit.z)
            for dx,dy in ((0,0),(-.8,0),(.8,0),(0,-.8),(0,.8)):
                start=Vector((point.x+dx,point.y+dy,foot+.15))
                for name,tree in trees:
                    hit,_,_,_=tree.ray_cast(start,Vector((0,0,1)),5.65)
                    if hit is not None and hit.z-foot>.6:
                        blocked.append({'route':route['name'],'mesh':name,'point':list(start),'ray':'vertical'})
            for h in (1,3.4,5.4):
                for axis in (Vector((1,0,0)),Vector((0,1,0))):
                    start=Vector((point.x,point.y,foot+h))-axis*.8
                    for name,tree in trees:
                        hit,_,_,_=tree.ray_cast(start,axis,1.6)
                        if hit is not None:blocked.append({'route':route['name'],'mesh':name,'point':list(start),'ray':'body cross'})
            samples+=1
print('ROUTES '+json.dumps({'samples':samples,'blocked':len(blocked),'firstFindings':blocked[:10]}),flush=True)

# Source stays editable and is not overwritten by this export conversion.
for obj in list(bpy.context.scene.objects):
    if obj not in objects:bpy.data.objects.remove(obj,do_unlink=True)
for obj in list(objects):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='MATERIAL');bpy.ops.object.mode_set(mode='OBJECT')
manifest=[]
override_path=out/'material-overrides.json'
overrides=json.loads(override_path.read_text()) if override_path.exists() else {}
for obj in list(bpy.context.scene.objects):
    used={p.material_index for p in obj.data.polygons};assert len(used)==1
    material=obj.data.materials[next(iter(used))]
    for face in obj.data.polygons:face.material_index=0
    obj.data.materials.clear();obj.data.materials.append(material)
    obj.name=obj.get('section',slug)+'_'+material.name
    node=material.node_tree.nodes.get('Principled BSDF')
    if node:node.inputs['Emission Strength'].default_value=0
    obj.hide_render=False
    settings=overrides.get(material.name,{})
    if node:node.inputs['Alpha'].default_value=1-settings.get('RobloxTransparency',0)
    manifest.append({'name':obj.name,'section':obj.get('section'), 'material':material.name,'colorRGB':r['paletteRGB'][material.name],'triangles':len(obj.data.polygons),'roblox':settings})
assert sum(m['triangles'] for m in manifest)==r['triangles']
assert all(m['triangles']<20000 for m in manifest)
bpy.ops.object.select_all(action='SELECT')
path=out/f'{house_slug(slug)}-roblox.fbx'
bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.fbx(filepath=str(path));bpy.context.view_layer.update()
imported=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(imported)==len(manifest) and all(len(o.data.materials)==1 for o in imported)
vertices=[o.matrix_world@v.co for o in imported for v in o.data.vertices]
bounds={k:[fn(v[i] for v in vertices) for i in range(3)] for k,fn in [('min',min),('max',max)]}
error=max(abs(bounds[k][i]-r['boundsBlender'][k][i]) for k in ('min','max') for i in range(3))
assert error<.001,error

root=E.Element('roblox',{'version':'4'});model=E.SubElement(root,'Item',{'class':'Model','referent':'house'})
def prop(p,kind,name,value):e=E.SubElement(p,kind,{'name':name});e.text=str(value);return e
def vec(p,name,v):
    e=E.SubElement(p,'Vector3',{'name':name})
    for k,x in zip(('X','Y','Z'),v):E.SubElement(e,k).text=str(x)
def cf(p,v,yaw=0.0):
    # A ROTATED BOX NEEDS ITS ROTATION, and this used to assert there were
    # none. That held for the slime, whose colliders are all axis-aligned, and
    # the treehouse has THIRTEEN rotated ones (its two stair flights) -- so the
    # assert stopped this script before it could write
    # `roblox-import-report.json`, which is the per-mesh COLOUR manifest that
    # `build_treehouse_runtime.py` reads and hard-fails without. The FBX was
    # written before the throw, so the symptom was a fresh model importing with
    # a stale manifest beside it.
    #
    # THE YAW IS +rotationZ, AND THIS SAID -rotationZ UNTIL 2026-09-23.
    # Blender (x,y,z) maps to (-x,z,y), and the tempting reading is that
    # negating x flips the sense of a z-rotation. It does not: that map is a
    # negate AND a y/z swap, which is two reflections, and two reflections
    # compose into a PROPER rotation (determinant +1) -- which preserves the
    # sense. See the note in `build_house_runtime.py`, which shipped the same
    # mistake into two house templates and cost the treehouse its stairs.
    c,sn=math.cos(yaw),math.sin(yaw)
    e=E.SubElement(p,'CoordinateFrame',{'name':'CFrame'})
    for k,x in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),(*v,c,0,sn,0,1,0,-sn,0,c)):E.SubElement(e,k).text=str(x)
def part(name,point,size,solid,ref,yaw=0.0):
    item=E.SubElement(model,'Item',{'class':'Part','referent':ref});p=E.SubElement(item,'Properties');prop(p,'string','Name',name)
    for key,value in [('Anchored',True),('CanCollide',solid),('CanQuery',solid),('CanTouch',False),('CastShadow',False)]:prop(p,'bool',key,str(value).lower())
    prop(p,'float','Transparency',1);vec(p,'size',size);cf(p,point,yaw);return item
p=E.SubElement(model,'Properties');prop(p,'string','Name',slug+'_DraftCollisionAndDisplayMounts');prop(p,'Ref','PrimaryPart','origin')
origin=part('Root',(0,0,0),(1,1,1),False,'origin')
for i,b in enumerate(r['collisionBoxesDraft']):
    x,y,z=b['blenderLocation'];sx,sy,sz=b['sizeXYZ']
    part(b['name'],(-x,z,y),(sx,sz,sy),True,'collision_'+str(i),b.get('rotationZ',0.0))
for name,(x,y,z) in r['mountsBlender'].items():
    item=E.SubElement(origin,'Item',{'class':'Attachment','referent':name});p=E.SubElement(item,'Properties');prop(p,'string','Name',name);cf(p,(-x,z,y))
E.indent(root);E.ElementTree(root).write(out/f'{house_slug(slug)}-collision-mounts.rbxmx',encoding='utf-8',xml_declaration=True)

result={'export':path.name,'meshCount':len(manifest),'triangles':r['triangles'],'singleMaterialPerMesh':True,'fbxRoundTripMaxBoundsError':error,'meshes':manifest,'collisionPartsDraft':len(r['collisionBoxesDraft']),'attachments':len(r['mountsBlender']),'basePartsWithCompanion':len(manifest)+len(r['collisionBoxesDraft'])+1,'routes':{'samples':samples,'blocked':blocked,'method':'five vertical rays and two body cross-rays at three heights, 1.6-unit footprint; floor sampled below each centre; unmodeled outside ground assumed at zero'},'studioChecks':'not performed; actual avatar collision, camera, material colours and scale pending','notes':'Preview awards and presentation objects excluded. No runtime menus or animations included. Companion is a draft, not certified collision.'}
(out/'roblox-import-report.json').write_text(json.dumps(result,indent=2))
print('IMPORT_REPORT '+json.dumps({k:result[k] for k in ('meshCount','triangles','basePartsWithCompanion','fbxRoundTripMaxBoundsError')}),flush=True)
assert not blocked,'Resolve sampled route findings before handoff'
