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
    for source in sources:bpy.data.objects.remove(source,do_unlink=True)
    (out/'beard-root-checks.json').write_text(json.dumps({'roots':root_checks,
        'snoutHalfWidthNative':snout_half_width,'allRootedOnCheeks':True},indent=2))
