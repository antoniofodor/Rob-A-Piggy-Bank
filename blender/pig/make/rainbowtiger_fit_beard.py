"""Fit the approved textured study onto the pig without rebuilding its locks."""
import bpy, math, shutil, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def fit_approved_beard(study, out, mesh):
    names=['RootPatch','LongOuter','LongBottom','ShortDown','ShortOut',
           'LowerSweep','UpperSweep','MiddleSweep']
    with bpy.data.libraries.load(str(study/'beard-shape-study.blend'),link=False) as (src,dst):
        dst.objects=names
    sources=dst.objects
    body=bpy.data.objects['Body']
    body_tree=BVHTree.FromPolygons([body.matrix_world@v.co for v in body.data.vertices],
                                  [list(p.vertices) for p in body.data.polygons])
    snout=bpy.data.objects['Snout']
    snout_half_width=max(abs((snout.matrix_world@v.co).x) for v in snout.data.vertices)
    snout_bottom=min((snout.matrix_world@v.co).z for v in snout.data.vertices)
    snout_tree=BVHTree.FromPolygons([snout.matrix_world@v.co for v in snout.data.vertices],
                                   [list(p.vertices) for p in snout.data.polygons])
    root_checks=[]
    material=sources[0].data.materials[0]
    material.name='RainbowTiger_ApprovedBeard'
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE':
            filename=node.image.name.split('.')[0]+'.png'
            shutil.copy2(study/filename,out/filename)
            node.image.filepath=str(out/filename)
    # Preserve the study's width while smoothly bending the lower locks inward.
    for side in (-1,1):
        verts=[];faces=[];face_uvs=[]
        for source in sources:
            start=len(verts)
            pxs=[v.co.x/.012+135 for v in source.data.vertices]
            pys=[170-v.co.z/.012 for v in source.data.vertices]
            cx=(min(pxs)+max(pxs))*.5;cy=(min(pys)+max(pys))*.5
            center_height=(cy-32)/289;center_u=(cx-25)/206
            turn=max(0,min(1,(cy-160)/135));turn=turn*turn*(3-2*turn)
            angle=.70*turn
            center_x=1.00-.53*center_u-.565*turn
            center_z=.34-(cy-32)*.00455+.11*turn
            if source.name=='LongBottom':center_x-=.10
            elif source.name=='UpperSweep':center_x+=.06
            elif source.name=='MiddleSweep':center_x+=.03
            fitted=[]
            for v in source.data.vertices:
                px=v.co.x/.012+135;py=170-v.co.z/.012
                height=(py-32)/289
                u=(px-25)/206
                chin=max(0,min(1,(py-160)/135));chin=chin*chin*(3-2*chin)
                dx=px-cx;dy=py-cy
                # Place and rotate whole locks: avoid shearing their approved
                # rounded middles into thin straps while bending around chin.
                x=center_x-.0040*(math.cos(angle)*dx+math.sin(angle)*dy)
                z=center_z+.0040*(math.sin(angle)*dx-math.cos(angle)*dy)
                y=-.38-.54*height-.37*u+v.co.y*.25-.12*chin+.12
                if source.name in ('UpperSweep','MiddleSweep','LowerSweep'):y-=.065
                if source.name=='LongBottom':z-=.08
                elif source.name=='LowerSweep':z-=.035
                if source.name=='LongBottom' and side>0:y-=.015
                fitted.append(Vector((side*x,y,z)))
            uv=source.data.uv_layers.active
            along={loop.vertex_index:uv.data[loop.index].uv.y for loop in source.data.loops}
            root_index=min(along,key=along.get)
            root=fitted[root_index]
            anchor=root.copy()
            if source.name=='LongBottom':anchor.x=side*.68;anchor.z=-.45
            hit=body_tree.ray_cast(Vector((anchor.x,-3,anchor.z)),Vector((0,1,0)),6)[0]
            assert hit is not None,('Beard root missed cheek',source.name,list(anchor))
            anchor.y=hit.y+.025
            assert abs(anchor.x)>snout_half_width+.05,('Root inside snout footprint',source.name)
            root_checks.append({'lock':source.name,'side':side,'anchorNative':list(anchor),
                                'bone':'Ruff_L' if side<0 else 'Ruff_R','attachment':'cheek',
                                'outsideSnoutWidth':abs(anchor.x)-snout_half_width,
                                'buriedInCheek':.025})
            root_shift=anchor-root
            for i,p in enumerate(fitted):
                p+=root_shift*(1-along[i])**3
                verts.append(tuple(p))
            for polygon in source.data.polygons:
                faces.append(tuple(start+i for i in polygon.vertices))
                face_uvs.append({start+source.data.loops[i].vertex_index:tuple(uv.data[i].uv)
                                 for i in polygon.loop_indices})
        ob=mesh('CheekFur_'+str(side),verts,faces,'Ruff','Ruff_L' if side<0 else 'Ruff_R')
        ob.data.materials.clear();ob.data.materials.append(material)
        uv=ob.data.uv_layers.new(name='FurFlowUV')
        for poly in ob.data.polygons:
            for i in poly.loop_indices:
                uv.data[i].uv=face_uvs[poly.index][ob.data.loops[i].vertex_index]
        for poly in ob.data.polygons:poly.use_smooth=True
        ob['colorTexture']='beard-flow-color.png';ob['normalTexture']='beard-flow-normal.png'
        ob['approvedStudy']='beard-shape-study/beard-shape-study.blend'

    # Extra overlapping locks fill the cheek triangle, then continue beneath
    # the snout. Use the approved outlines and texture coordinates unchanged.
    extra_groups={}
    by_name={o.name:o for o in sources}
    def add_lock(label,source_name,root_xz,tip_xz,tip_y,side,bone,attachment,depth=.24):
        source=by_name[source_name];uv=source.data.uv_layers.active
        along={loop.vertex_index:uv.data[loop.index].uv.y for loop in source.data.loops}
        root_i=min(along,key=along.get);tip_i=max(along,key=along.get)
        original_root=source.data.vertices[root_i].co
        original_tip=source.data.vertices[tip_i].co
        start_2d=Vector((-original_root.x,original_root.z))
        source_dir=Vector((-original_tip.x,original_tip.z))-start_2d
        root=Vector((side*root_xz[0],0,root_xz[1]))
        if attachment=='cheek':
            hit=body_tree.ray_cast(Vector((root.x,-3,root.z)),Vector((0,1,0)),6)[0]
            assert hit is not None,('Extra root missed body',label)
            root.y=hit.y+.025
            assert abs(root.x)>snout_half_width+.05
        else:
            root.y=-1.04
            hit,normal,_,_=snout_tree.ray_cast(Vector((root.x,root.y,-3)),Vector((0,0,1)),6)
            assert hit is not None and normal.z<-.2,('Chin missed snout underside',label)
            root.z=hit.z+.018
            root_xz=(root_xz[0],root.z)
        target_dir=Vector(tip_xz)-Vector(root_xz)
        scale=target_dir.length/source_dir.length
        angle=math.atan2(target_dir.y,target_dir.x)-math.atan2(source_dir.y,source_dir.x)
        root_checks.append({'lock':label,'side':side,'bone':bone,'attachment':attachment,
                            'anchorNative':list(root),'outsideSnoutWidth':abs(root.x)-snout_half_width,
                            'attachmentSurfaceNative':list(hit),'rootInset':.025 if attachment=='cheek' else .018})
        group=('CheekFill_'+str(side)) if attachment=='cheek' else 'BeardFur'
        verts,faces,face_uvs=extra_groups.setdefault((group,bone),([],[],[]))
        start=len(verts)
        for v in source.data.vertices:
            t=along[v.index];delta=Vector((-v.co.x,v.co.z))-start_2d
            x=root_xz[0]+scale*(math.cos(angle)*delta.x-math.sin(angle)*delta.y)
            z=root_xz[1]+scale*(math.sin(angle)*delta.x+math.cos(angle)*delta.y)
            # Root cap is buried in the cheek/jaw; the broad middle sits above
            # the coat and the tip follows the snout rim without rooting there.
            ease=1-(1-t)**3
            y=root.y*(1-ease)+tip_y*ease+(v.co.y-original_root.y)*depth
            verts.append((side*x,y,z))
        for polygon in source.data.polygons:
            faces.append(tuple(start+i for i in polygon.vertices))
            face_uvs.append({start+source.data.loops[i].vertex_index:tuple(uv.data[i].uv)
                             for i in polygon.loop_indices})

    for side in (-1,1):
        bone='Ruff_L' if side<0 else 'Ruff_R'
        add_lock('InnerCheekUpper','UpperSweep',(.78,.23),(.49,.12),-1.00,side,bone,'cheek')
        add_lock('InnerCheekLower','MiddleSweep',(.79,.075),(.50,-.15),-1.035,side,bone,'cheek')
        add_lock('UnderSnoutSide','LowerSweep',(.27,-.70),(.10,-.91),-1.10,side,'Root','undersnout',.23)
    add_lock('UnderSnoutCenter','LowerSweep',(.00,-.70),(-.015,-.95),-1.115,1,'Root','undersnout',.24)
    for (name,bone),(verts,faces,face_uvs) in extra_groups.items():
        ob=mesh(name,verts,faces,'Ruff',bone)
        ob.data.materials.clear();ob.data.materials.append(material)
        uv=ob.data.uv_layers.new(name='FurFlowUV')
        for poly in ob.data.polygons:
            poly.use_smooth=True
            for i in poly.loop_indices:uv.data[i].uv=face_uvs[poly.index][ob.data.loops[i].vertex_index]
        ob['colorTexture']='beard-flow-color.png';ob['normalTexture']='beard-flow-normal.png'
        ob['approvedStudy']='beard-shape-study/beard-shape-study.blend'
    for source in sources:bpy.data.objects.remove(source,do_unlink=True)
    (out/'beard-root-checks.json').write_text(json.dumps({'roots':root_checks,
        'snoutHalfWidthNative':snout_half_width,'snoutBottomNative':snout_bottom,
        'allRootedOnCheeksOrUnderSnout':True},indent=2))
