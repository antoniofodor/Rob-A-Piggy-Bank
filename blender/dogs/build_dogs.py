"""Author three distinct low-poly guard dogs in Blender.

Blender -b --factory-startup -t 4 --python blender/dogs/build_dogs.py
Use DOG_BREED=terrier|shepherd|mastiff for one breed; DOG_QUICK=1 for beauty only.
Coordinates: Blender Z up, nose toward -Y; GLB Y up, nose toward +Z.
Dimensions are final tier sizes, not a shared mesh awaiting tier deformation.
"""
import bpy
import math
import json
import os
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/dogs'
sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_glb import export_glb

BREEDS = {
    'terrier': dict(label='Scruffy', fur=(198,154,98), dark=(158,116,68), collar=(214,68,64),
                    bodyZ=1.45, width=.63, length=1.25, bodyH=.62, headZ=2.20,
                    headY=-1.32, headW=.59, headD=.53, headH=.59, muzzle=.62,
                    legX=.48, frontY=-.77, rearY=.83, foot=.27),
    'shepherd': dict(label='Rex', fur=(126,94,66), dark=(72,52,38), collar=(66,140,220),
                     bodyZ=2.01, width=.73, length=1.62, bodyH=.79, headZ=3.00,
                     headY=-1.67, headW=.63, headD=.59, headH=.67, muzzle=.89,
                     legX=.58, frontY=-1.05, rearY=1.02, foot=.29),
    'mastiff': dict(label='Titan', fur=(58,56,64), dark=(32,31,37), collar=(246,198,52),
                    bodyZ=1.95, width=1.06, length=1.65, bodyH=.98, headZ=2.96,
                    headY=-1.68, headW=.95, headD=.74, headH=.84, muzzle=.65,
                    legX=.82, frontY=-1.07, rearY=1.07, foot=.39),
}


def linear(c):
    c /= 255
    return c / 12.92 if c <= .04045 else ((c+.055)/1.055)**2.4


def material(name, rgb, roughness=.82):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*map(linear, rgb), 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = m.diffuse_color
    p.inputs['Roughness'].default_value = roughness
    return m


def active(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def finish(obj, name, mat, group, tone, pivot=None):
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj['group'], obj['tone'] = group, tone
    active(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for p in obj.data.polygons:
        p.use_smooth = False
    if pivot is not None:
        bpy.context.scene.cursor.location = pivot
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return obj


def ell(loc, radius, subdivisions=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=loc)
    o = bpy.context.object
    o.scale = radius
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def fuse(name, shapes, mat, group, tone, budget, voxel=.065, pivot=None):
    objs = [ell(pos, scale) for pos, scale in shapes]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object
    r = o.modifiers.new('Continuous sculpted silhouette', 'REMESH')
    r.mode, r.voxel_size = 'VOXEL', voxel
    bpy.ops.object.modifier_apply(modifier=r.name)
    s = o.modifiers.new('Blend anatomical junctions', 'SMOOTH')
    s.factor, s.iterations = .75, 4
    bpy.ops.object.modifier_apply(modifier=s.name)
    o.data.calc_loop_triangles()
    d = o.modifiers.new('Flat-shaded game topology', 'DECIMATE')
    d.ratio = min(1, budget/max(1,len(o.data.loop_triangles)))
    bpy.ops.object.modifier_apply(modifier=d.name)
    return finish(o, name, mat, group, tone, pivot)


def piece(name, loc, radius, mat, group, tone, subs=2, pivot=None):
    return finish(ell(loc, radius, subs), name, mat, group, tone, pivot)


def mesh(name, verts, faces, mat, group, tone, pivot=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    active(obj)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return finish(obj, name, mat, group, tone, pivot)


def tube(name, points, mat, group, tone, sides=10, pivot=None):
    verts, faces = [], []
    previous_u=None
    for j, (x,y,z,r) in enumerate(points):
        here = Vector((x,y,z))
        before = Vector(points[max(0,j-1)][:3])
        after = Vector(points[min(len(points)-1,j+1)][:3])
        direction = (after-before).normalized()
        if previous_u is None:
            helper = Vector((1,0,0)) if abs(direction.x)<.85 else Vector((0,1,0))
            u = direction.cross(helper).normalized()
        else:
            u=(previous_u-direction*previous_u.dot(direction)).normalized()
        previous_u=u
        v = direction.cross(u).normalized()
        for i in range(sides):
            angle = i*math.tau/sides
            verts.append(tuple(here+r*(u*math.cos(angle)+v*math.sin(angle))))
    for j in range(len(points)-1):
        for i in range(sides):
            a=j*sides+i; b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))), tuple((len(points)-1)*sides+i for i in range(sides))]
    return mesh(name, verts, faces, mat, group, tone, pivot)


def ring(name, center, rx, ry, height, mat, group='body', tone='collar'):
    x,y,z = center
    verts, faces = [], []
    n=20
    for dz, scale in [(-height/2,1),(height/2,1),(-height/2,.86),(height/2,.86)]:
        for i in range(n):
            a=i*math.tau/n
            verts.append((x+rx*scale*math.cos(a),y+ry*scale*math.sin(a),z+dz))
    for i in range(n):
        k=(i+1)%n
        faces.extend([(i,k,n+k,n+i),(2*n+i,3*n+i,3*n+k,2*n+k),
                      (n+i,n+k,3*n+k,3*n+i),(i,2*n+i,2*n+k,k)])
    return mesh(name,verts,faces,mat,group,tone,center)


def ear(name, side, root, width, height, mat, inner, folded=False):
    x,y,z=root
    tip=(x+side*width*.23,y+.07,z+height)
    if folded:
        tip=(x+side*width*.48,y-.26,z+height*.71)
    verts=[(x-width/2,y,z),(x+width/2,y,z),tip,(x,y-.18,z+height*.35),
           (x-width*.44,y+.18,z+.04),(x+width*.44,y+.18,z+.04),
           (tip[0],tip[1]+.13,tip[2]-.035)]
    faces=[(0,1,3),(1,2,3),(2,0,3),(4,6,5),(0,4,5,1),(1,5,6,2),(2,6,4,0)]
    outer=mesh(name,verts,faces,mat,'ear','fur',root)
    inset=[(x-width*.27,y-.07,z+height*.16),
           (x+width*.27,y-.07,z+height*.16),
           (x+side*width*.16,tip[1]-.035,z+height*(.61 if folded else .78)),
           (x,y-.196,z+height*.35)]
    # Solid inset is offset from the visible ear face, not coplanar.
    back=[(a,b+.035,c) for a,b,c in inset]
    infaces=[(0,1,3),(1,2,3),(2,0,3),(4,7,5),(5,7,6),(6,7,4),
             (0,4,5,1),(1,5,6,2),(2,6,4,0)]
    inside=mesh(name+'_Inset',inset+back,infaces,inner,'ear','dark',root)
    return [outer,inside]


def build(breed):
    p=BREEDS[breed]
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    mats={k:material(breed+'_'+k,p[k]) for k in ('fur','dark','collar')}
    mats['eye']=material('Eyes_nose_mouth',(23,21,25),.35)
    mats['highlight']=material('Eye_glint_fixed',(244,238,219),.28)
    objects=[]
    add=lambda o: objects.append(o) or o
    z,w,L,h=p['bodyZ'],p['width'],p['length'],p['bodyH']
    hy,hz,hw,hd,hh=p['headY'],p['headZ'],p['headW'],p['headD'],p['headH']
    neck=(0,hy+.28,hz-.55)
    add(fuse('Body',[
        ((0,-.22,z),(w,L*.81,h)),
        ((0,-L*.55,z+.02),(w*1.02,L*.43,h*1.12)),
        ((0,L*.58,z-.03),(w*.84,L*.46,h*.88)),
        (neck,(hw*.82,.61,hh*.99)),
    ],mats['fur'],'body','fur',1000,pivot=(0,0,z)))
    # Broad brow, cheek planes, and a real projecting muzzle, rather than cubes.
    add(fuse('Head',[
        ((0,hy,hz),(hw,hd,hh)),
        ((-hw*.51,hy-.11,hz-.19),(hw*.51,hd*.69,hh*.62)),
        ((hw*.51,hy-.11,hz-.19),(hw*.51,hd*.69,hh*.62)),
    ],mats['fur'],'head','fur',760,voxel=.045,pivot=(0,hy+.18,hz-.38)))
    muzzleW=hw*(.68 if breed=='mastiff' else .55)
    muzzleY=hy-hd*.55-p['muzzle']*.31
    muzzleZ=hz-hh*.35
    muzzleMat=mats['dark'] if breed!='terrier' else mats['fur']
    muzzleTone='dark' if breed!='terrier' else 'fur'
    shapes=[((0,muzzleY,muzzleZ),(muzzleW,p['muzzle']*.70,hh*.36))]
    if breed=='mastiff':
        shapes += [((s*hw*.32,muzzleY+.015,muzzleZ-.17),(hw*.37,.47,.40)) for s in (-1,1)]
    add(fuse('Muzzle',shapes,muzzleMat,'head',muzzleTone,420,voxel=.038,pivot=(0,hy+.18,hz-.38)))
    noseY=muzzleY-p['muzzle']*.62
    add(piece('Nose',(0,noseY,muzzleZ+.07),(muzzleW*.64,.16 if breed!='mastiff' else .22,.18 if breed!='mastiff' else .23),mats['eye'],'head','eye'))
    # Clean mouth seam below the muzzle. No visible teeth or aggressive snarl.
    add(tube('Mouth',[
        (-muzzleW*.66,muzzleY-.30,muzzleZ-.12,.023),
        (-muzzleW*.32,noseY+.07,muzzleZ-.18,.023),
        (0,noseY+.015,muzzleZ-.19,.023),
        (muzzleW*.32,noseY+.07,muzzleZ-.18,.023),
        (muzzleW*.66,muzzleY-.30,muzzleZ-.12,.023),
    ],mats['eye'],'head','eye',sides=6))
    eyeY=hy-hd*.81
    for side,label in [(-1,'L'),(1,'R')]:
        ex=side*hw*.60; ez=hz+hh*.16
        add(piece('Eye_'+label,(ex,eyeY,ez),(.128,.082,.145) if breed!='mastiff' else (.15,.09,.15),mats['eye'],'head','eye'))
        add(piece('EyeGlint_'+label,(ex-.035,eyeY-.077,ez+.041),(.034,.020,.038),mats['highlight'],'head','fixed',subs=1))
        brow=piece('Brow_'+label,(ex,eyeY+.018,ez+.18),(hw*.28,.16,.11),mats['fur'],'head','fur')
        brow.rotation_euler.y=side*-.11
        add(brow)
        if breed=='mastiff':
            root=(side*hw*.83,hy+.08,hz+hh*.43)
            e=fuse('Ear_'+label,[
                (root,(.26,.34,.34)),
                ((side*hw*1.02,hy+.10,hz+.10),(.27,.34,.42)),
                ((side*hw*1.10,hy-.03,hz-.22),(.25,.30,.33)),
            ],mats['dark'],'ear','dark',240,voxel=.045,pivot=root)
            add(e)
        else:
            root=(side*hw*.69,hy+.06,hz+hh*.64)
            objects.extend(ear('Ear_'+label,side,root,.56 if breed=='shepherd' else .48,
                               1.01 if breed=='shepherd' else .76,
                               mats['fur'],mats['dark'],folded=(breed=='terrier' and side==1)))
    if breed=='terrier':
        # Angular beard and cheek tufts are breed features, not noisy hair cards.
        for side,label in [(-1,'L'),(1,'R')]:
            add(tube('CheekTuft_'+label,[(side*.45,hy-.16,hz-.12,.24),
                    (side*.65,hy-.29,hz-.34,.22),(side*.73,hy-.33,hz-.52,.025)],
                    mats['fur'],'head','fur',sides=6,pivot=(0,hy+.18,hz-.38)))
        add(tube('Beard',[(0,muzzleY+.08,muzzleZ-.10,.29),
                         (0,muzzleY-.06,muzzleZ-.40,.24),(0,muzzleY-.09,muzzleZ-.56,.025)],
                         mats['fur'],'head','fur',sides=7,pivot=(0,hy+.18,hz-.38)))
    # Separate left/right front and hind legs, joint origins at shoulders/hips.
    for side,label in [(-1,'L'),(1,'R')]:
        for front,prefix,y in [(True,'Front',p['frontY']),(False,'Hind',p['rearY'])]:
            x=side*p['legX']; r=p['foot']
            hip=(x,y,z-.06)
            if front:
                shapes=[((x,y,z-.22),(r*.91,r*1.06,h*.82)),
                        ((x,y-.06,z*.36),(r*.70,r*.80,z*.35))]
            else:
                shapes=[((x,y,z-.13),(r*1.2,r*1.4,h*.85)),
                        ((x,y+.27,.77),(r*.75,r*.84,.48)),
                        ((x,y+.10,.43),(r*.62,r*.72,.31))]
            add(fuse(prefix+'Leg_'+label,shapes,mats['fur'],'leg','fur',270,voxel=.045,pivot=hip))
            py=y-.10 if front else y+.01
            add(piece(prefix+'Paw_'+label,(x,py-.15,.20),(r*1.02,r*1.47,.205),mats['fur'],'paw','fur',pivot=(x,py,.29)))
            # Recessed-looking toe creases use tiny separate black geometry.
            for k in (-1,1):
                add(tube(prefix+'Toe_'+label+str(k),[(x+k*r*.27,py-r*1.32,.135,.018),
                          (x+k*r*.27,py-r*1.14,.245,.016)],mats['dark'],'paw','dark',sides=5,pivot=(x,py,.29)))
    tailRoot=(0,L*.72,z+.25)
    if breed=='terrier':
        tail=[(*tailRoot,.18),(0,L+.15,z+.52,.17),(.08,L+.34,z+1.0,.12),(.17,L+.32,z+1.32,.025)]
    elif breed=='shepherd':
        tail=[(*tailRoot,.25),(0,L+.31,z-.14,.33),(.09,L+.76,z-.76,.32),
              (.23,L+.96,z-1.18,.22),(.40,L+1.05,z-1.30,.025)]
    else:
        tail=[(*tailRoot,.22),(.12,L+.29,z+.04,.20),(.35,L+.63,z-.36,.15),
              (.65,L+.81,z-.47,.10),(.82,L+.86,z-.28,.018)]
    add(tube('Tail',tail,mats['dark'] if breed=='shepherd' else mats['fur'],'tail',
             'dark' if breed=='shepherd' else 'fur',sides=10,pivot=tailRoot))
    # A true wraparound band, independently tintable for purchased collars.
    cz=hz-hh*.79
    collarCenter=(0,hy+.25,cz)
    add(ring('Collar',collarCenter,hw*.90,.65 if breed!='mastiff' else .79,.20 if breed!='mastiff' else .25,mats['collar']))
    tagY=collarCenter[1]-(.65 if breed!='mastiff' else .79)-.02
    add(piece('Tag',(0,tagY,cz-.20),(.13,.06,.17),mats['collar'],'body','collar'))
    if breed=='shepherd':
        # Split a color region out of the actual torso surface. Shared boundary
        # vertices keep the marking flush, with no layered armor or z-fighting.
        body=objects[0]
        verts, faces, remain=[],[],[]
        for f in body.data.polygons:
            center=body.matrix_world@f.center
            normal=body.matrix_world.to_3x3()@f.normal
            if center.z>z+.18 and -.66<center.y<L*.66 and normal.z>.12:
                face=[]
                for vi in f.vertices:
                    v=body.matrix_world@body.data.vertices[vi].co
                    face.append(len(verts));verts.append(tuple(v))
                faces.append(tuple(face))
            else:
                remain.append(tuple(f.vertices))
        bodyMesh=bpy.data.meshes.new('Body coat surface')
        bodyMesh.from_pydata([tuple(v.co) for v in body.data.vertices],[],remain)
        bodyMesh.update();body.data=bodyMesh;body.data.materials.append(mats['fur'])
        saddle=mesh('Saddle',verts,faces,mats['dark'],'body','dark',(0,0,z))
        # Weld shared vertices without displacing the exact coat boundary.
        active(saddle)
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.remove_doubles(threshold=.00001);bpy.ops.object.mode_set(mode='OBJECT')
        add(saddle)
    # Keep fur tufts and toe details with the matching articulated part and tone.
    for o in objects:
        active(o)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.quads_convert_to_tris(quad_method='BEAUTY',ngon_method='BEAUTY')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        for f in o.data.polygons: f.use_smooth=False
    return objects, mats


def lighting(scene):
    scene.render.engine='CYCLES'
    scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1100;scene.render.resolution_y=1000
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=False
    scene.view_settings.view_transform='AgX'
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.24,.31,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
    def area(name,position,energy,size):
        bpy.ops.object.light_add(type='AREA',location=position)
        o=bpy.context.object;o.name=name;o.data.energy=energy;o.data.shape='DISK';o.data.size=size
        o.rotation_euler=(Vector((0,0,1.8))-o.location).to_track_quat('-Z','Y').to_euler()
    area('Key softbox',(-4,-6,9),950,5)
    area('Fill softbox',(6,-2,5),700,5)
    area('Rim softbox',(0,6,8),1200,4)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.035))
    ground=bpy.context.object;ground.name='Studio floor - not exported'
    ground.data.materials.append(material('Studio warm grey',(183,190,194)))
    bpy.ops.object.camera_add(location=(7,-10,5.7))
    camera=bpy.context.object;camera.name='Preview camera';camera.data.type='ORTHO'
    scene.camera=camera
    return camera


def report(objects, breed):
    data={'breed':breed,'name':BREEDS[breed]['label'],'authoredIn':'Blender',
          'units':'1 unit = 1 intended stud. GLB +Y up, +Z forward.',
          'sizing':'Final tier proportions; do not reapply DOG_TIERS.scale/shape.',
          'rig':'Separate static parts with joint origins; no skeletal animations.',
          'installedInGame':False,'parts':{},'triangles':0}
    allv=[]
    for o in objects:
        o.data.calc_loop_triangles()
        coords=[o.matrix_world@v.co for v in o.data.vertices]
        allv+=coords
        t=len(o.data.loop_triangles)
        assert 0<t<10000,(o.name,t)
        data['triangles']+=t
        data['parts'][o.name]={'triangles':t,'tone':o['tone'],'group':o['group'],
                              'originBlender':list(o.matrix_world.translation),
                              'material':o.data.materials[0].name}
    mins=[min(v[i] for v in allv) for i in range(3)]
    maxs=[max(v[i] for v in allv) for i in range(3)]
    data['sizeRoblox']=[maxs[0]-mins[0],maxs[2]-mins[2],maxs[1]-mins[1]]
    data['boundsBlender']={'min':mins,'max':maxs}
    return data


def run():
    keys=[os.environ['DOG_BREED']] if os.environ.get('DOG_BREED') else list(BREEDS)
    for breed in keys:
        folder=OUT/breed;folder.mkdir(parents=True,exist_ok=True)
        objects,mats=build(breed)
        bpy.context.view_layer.update()
        stats=report(objects,breed)
        export_glb(objects,folder/(breed+'.glb'))
        (folder/(breed+'-report.json')).write_text(json.dumps(stats,indent=2)+'\n')
        scene=bpy.context.scene
        camera=lighting(scene)
        height=stats['sizeRoblox'][1]
        camera.data.ortho_scale=max(stats['sizeRoblox'][2]*1.20,height*1.50)
        target=Vector((0,-.06,height*.48))
        for name,pos in [('three-quarter',(7,-11,6.5)),('side',(12,-.1,4.1)),('front',(0,-13,4.4)),('rear',(7,12,5.5))]:
            if os.environ.get('DOG_QUICK') and name!='three-quarter':continue
            scene.cycles.samples=32 if name=='three-quarter' else 16
            scene.render.resolution_x=1100 if name=='three-quarter' else 840
            scene.render.resolution_y=1000 if name=='three-quarter' else 800
            camera.location=pos
            camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(folder/(breed+'-'+name+'.png'))
            bpy.ops.render.render(write_still=True)
        camera.location=(7,-11,6.5)
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.resolution_x=1100;scene.render.resolution_y=1000
        scene.cycles.samples=32
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type=='VIEW_3D':
                    area.spaces.active.shading.color_type='MATERIAL'
                    area.spaces.active.region_3d.view_distance=camera.data.ortho_scale*1.5
                    area.spaces.active.region_3d.view_location=target
        bpy.ops.wm.save_as_mainfile(filepath=str(folder/(breed+'.blend')))
        print('DOG_RESULT',breed,stats['triangles'],stats['sizeRoblox'],flush=True)


if __name__=='__main__':
    run()
