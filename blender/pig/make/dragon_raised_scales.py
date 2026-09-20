"""Closed beveled scale plates clipped onto the original pig surface.

A deterministic 3D Voronoi partitions the actual triangles. Boundary loops
become shallow, individually closed plates; no bump-map illusion or UV seams.
"""
import math,random
from collections import defaultdict
import bpy
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

STEP=Vector((.245,.205,.245))
N=Vector((0,math.sqrt(36-1.9**2),-1.9)).normalized()
PALETTE={'ScaleDark':(35,54,40),'ScaleMid':(44,68,46),'ScaleLit':(56,81,51),'ScaleOlive':(67,83,49)}

def guard(p,kind):
    if kind=='Body':
        # Leave the original flush plate seating annulus and deposit slit bare.
        if p.dot(N)>.65 and (p-N*p.dot(N)).length<.335:return True
        if p.z>.78 and abs(p.x)<.085 and abs(p.y)<.31:return True
    if kind=='Legs' and p.z<-.985:return True
    return False

def exterior(poly,ob):
    p=poly.center;n=poly.normal
    if ob.name=='Body':return p.length>.80 and n.dot(p.normalized())>.45
    if ob.name=='Ears':return poly.material_index!=(2 if ob.get('dragonUndercoat') else 1)
    return True

def build(obs,make_mesh):
    points=[]
    for i in range(-8,9):
        for j in range(-10,12):
            for k in range(-8,10):
                rng=random.Random((i+20)*73856093+(j+20)*19349663+(k+20)*83492791)
                points.append(Vector((i+.5+rng.uniform(-.22,.22),j+.5+rng.uniform(-.22,.22),k+.5+rng.uniform(-.22,.22))))
    kd=KDTree(len(points))
    for i,p in enumerate(points):kd.insert(p,i)
    kd.balance();neighbors={};buckets={};counts={};failed=0;seams={}
    def scaled(p):return Vector((p.x/STEP.x,p.y/STEP.y,p.z/STEP.z))
    def unscaled(p):return Vector((p.x*STEP.x,p.y*STEP.y,p.z*STEP.z))
    def clip(polygon,normal,d):
        out=[];a=polygon[-1];da=a.dot(normal)-d
        for b in polygon:
            db=b.dot(normal)-d
            if (da<=1e-8)!=(db<=1e-8):out.append(a.lerp(b,da/(da-db)))
            if db<=1e-8:out.append(b)
            a,da=b,db
        return out
    for ob in obs:
        ob.data.calc_loop_triangles();patches=defaultdict(list)
        tree=BVHTree.FromPolygons([v.co for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons])
        for tri in ob.data.loop_triangles:
            poly=ob.data.polygons[tri.polygon_index]
            if not exterior(poly,ob):continue
            vs=[scaled(ob.data.vertices[i].co) for i in tri.vertices];centroid=sum(vs,Vector())/3
            candidates={i for p in [centroid,*vs] for _,i,_ in kd.find_n(p,8)}
            for index in candidates:
                seed=points[index]
                if index not in neighbors:
                    neighbors[index]=[(points[j]-seed,(points[j].length_squared-seed.length_squared)/2) for _,j,_ in kd.find_n(seed,40) if j!=index]
                polygon=vs[:]
                for normal,d in neighbors[index]:
                    polygon=clip(polygon,normal,d)
                    if len(polygon)<3:break
                if len(polygon)>=3:patches[index].append([unscaled(p) for p in polygon])
        count=0
        for index,polygons in patches.items():
            coords={};edges=defaultdict(int)
            for polygon in polygons:
                keys=[]
                for p in polygon:
                    key=tuple(round(c,5) for c in p);coords[key]=p
                    if not keys or key!=keys[-1]:keys.append(key)
                if len(keys)>1 and keys[-1]==keys[0]:keys.pop()
                for a,b in zip(keys,keys[1:]+keys[:1]):
                    if a!=b:edges[tuple(sorted((a,b)))]+=1
            adjacent=defaultdict(list)
            for (a,b),n in edges.items():
                if n==1:adjacent[a].append(b);adjacent[b].append(a)
            if not adjacent or any(len(v)!=2 for v in adjacent.values()):failed+=1;continue
            start=next(iter(adjacent));loop=[start];prev=None;at=start
            while True:
                nxt=next((v for v in adjacent[at] if v!=prev),None)
                if nxt==start:break
                if nxt is None or nxt in loop:break
                loop.append(nxt);prev,at=at,nxt
            if len(loop)!=len(adjacent) or len(loop)<3:failed+=1;continue
            ring=[coords[k] for k in loop]
            # Remove tiny triangle subdivisions along a scale edge, while
            # retaining actual corners and the body's broad curvature.
            changed=True
            while changed and len(ring)>5:
                changed=False
                for i,p in enumerate(ring):
                    a,b=ring[i-1],ring[(i+1)%len(ring)];d=b-a
                    if d.length_squared<1e-10:continue
                    t=max(0,min(1,(p-a).dot(d)/d.length_squared))
                    if (p-(a+d*t)).length<.005:
                        ring.pop(i);changed=True;break
            center=sum(ring,Vector())/len(ring)
            # Trim boundary cells at a local tangent to the plate seat, instead
            # of discarding an entire scale-sized ring around the opening.
            if ob.name=='Body':
                radial=center-N*center.dot(N)
                if any(p.dot(N)>.65 and (p-N*p.dot(N)).length<.345 for p in ring):
                    if radial.length<.01:continue
                    ring=clip(ring,-radial.normalized(),-.345)
                if ring and any(p.z>.78 and abs(p.x)<.095 and abs(p.y)<.32 for p in ring):
                    if abs(center.x)/.095>=abs(center.y)/.32:
                        side=1 if center.x>=0 else -1;ring=clip(ring,Vector((-side,0,0)),-.095)
                    else:
                        side=1 if center.y>=0 else -1;ring=clip(ring,Vector((0,-side,0)),-.32)
            elif ob.name=='Legs':ring=clip(ring,Vector((0,0,-1)),.975)
            if len(ring)<3:continue
            center=sum(ring,Vector())/len(ring);hit,n,_,dist=tree.find_nearest(center)
            if hit is None or dist>.065:continue
            # No bridges across ear creases, connected-component gaps or slots.
            if any((p-center).length>.25 for p in ring):continue
            if ob.name=='Body' and (n.dot(center.normalized())<.4 or center.length<.78):continue
            center=hit;normals=[]
            for p in ring:
                _,normal,_,_=tree.find_nearest(p);normals.append(normal)
            if any(normal.dot(n)<.15 for normal in normals):continue
            rng=random.Random(index*31+7);tone=rng.choices(list(PALETTE),[.22,.45,.26,.07])[0]
            key=(ob['bone'],tone);verts,faces=buckets.setdefault(key,([],[]));base=len(verts);num=len(ring)
            height=.020+rng.random()*.006
            # Bottom skirt sits inside the original surface. Bevel edge is
            # raised 0.006; crown is raised 0.020–0.026 native units.
            for inset,rise in ((.935,-.015),(.935,.006),(.83,height)):
                for p,normal in zip(ring,normals):
                    q=center.lerp(p,inset);surface,nn,_,_=tree.find_nearest(q)
                    verts.append(tuple(surface+nn*rise))
            verts.extend([tuple(center+n*(height+.002)),tuple(center-n*.015)])
            # A temporary white ribbon marks only this plate's narrow border.
            # Project it onto the original UVs as emission, so omitted edge
            # cells and opening clearances never become solid orange patches.
            sv,sf=seams.setdefault(ob.name,([],[]));sb=len(sv)
            for inset in (1.0,.925):
                for p in ring:
                    surface,normal,_,_=tree.find_nearest(center.lerp(p,inset))
                    sv.append(tuple(surface+normal*.004))
            for j in range(num):sf.append((sb+j,sb+(j+1)%num,sb+num+(j+1)%num,sb+num+j))
            for j in range(num):
                k=(j+1)%num
                faces.extend([(base+j,base+k,base+num+k,base+num+j),(base+num+j,base+num+k,base+2*num+k,base+2*num+j),(base+2*num+j,base+2*num+k,base+3*num),(base+k,base+j,base+3*num+1)])
            count+=1
        counts[ob.name]=count
        print('RAISED_SCALES_PART',ob.name,count,flush=True)
    for (bone,tone),(verts,faces) in buckets.items():make_mesh('RaisedScales_'+bone+'_'+tone,verts,faces,tone,bone)
    assert counts.get('Body',0)>150,counts
    white=bpy.data.materials.new('BAKE_SeamWhite');white.use_nodes=True;nt=white.node_tree;nt.nodes.clear()
    em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(1,1,1,1);output=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(em.outputs[0],output.inputs['Surface'])
    sources={}
    for name,(verts,faces) in seams.items():
        data=bpy.data.meshes.new('BAKE_Seams_'+name);data.from_pydata(verts,[],faces);data.update()
        ob=bpy.data.objects.new(data.name,data);bpy.context.scene.collection.objects.link(ob);data.materials.append(white);sources[name]=ob
    return dict(platesByPart=counts,totalPlates=sum(counts.values()),heightNative=[.020,.028],heightStuds=[.12,.168],method='Closed beveled Voronoi scale plates clipped onto original mesh surfaces',boundaryCellsSkipped=failed),sources

def bake_seams(sources,materials,out,select,linear):
    """Project the actual geometry's seams, then bake matching opaque colors."""
    scene=bpy.context.scene;scene.render.bake.use_selected_to_active=True;scene.render.bake.use_clear=False
    scene.render.bake.cage_extrusion=.035;scene.render.bake.max_ray_distance=.075;scene.render.bake.margin=3
    # Hide raised plates from the explicit bake selection, not from delivery.
    reports=[]
    for group,names in [('body',['Body']),('trim',['Snout','Ears','Legs','Tail'])]:
        m=materials[group];nt=m.node_tree;b=nt.nodes['Principled BSDF']
        masknode=next(n for n in nt.nodes if n.label=='Scale seam mask')
        color=next(n for n in nt.nodes if n.label=='Scale undercoat color')
        mask=bpy.data.images.new('Dragon_'+group+'_ActualSeams',1024,1024,alpha=False);mask.colorspace_settings.name='Non-Color'
        target=nt.nodes.new('ShaderNodeTexImage');target.image=mask;nt.nodes.active=target
        for name in names:
            if name not in sources:continue
            select([bpy.data.objects[name],sources[name]])
            bpy.ops.object.bake(type='EMIT')
        mask.filepath_raw=str(out/f'dragon_{group}_emissive.png');mask.file_format='PNG';mask.save();mask.pack();masknode.image=mask
        pixels=np.asarray(mask.pixels[:]).reshape(-1,4)
        coverage=float((pixels[:,0]>.1).mean())
        assert .003<coverage<.30,(group,coverage)
        assert np.max(np.abs(pixels[:,0]-pixels[:,1]))<1e-6
        reports.append(dict(group=group,maskCoverageAboveTenPercent=coverage,source='Projected borders of the actual raised scale geometry'))
        scene.render.bake.use_selected_to_active=False;scene.render.bake.use_clear=True
        newcolor=bpy.data.images.new('Dragon_'+group+'_RaisedCoat',1024,1024,alpha=False);target.image=newcolor
        mix=nt.nodes.new('ShaderNodeMixRGB');nt.links.new(masknode.outputs['Color'],mix.inputs[0]);nt.links.new(color.outputs['Color'],mix.inputs[1]);mix.inputs[2].default_value=(*linear((232,105,24)),1)
        emission=nt.nodes.new('ShaderNodeEmission');nt.links.new(mix.outputs[0],emission.inputs['Color'])
        output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');nt.links.new(emission.outputs[0],output.inputs['Surface'])
        select([bpy.data.objects[n] for n in names]);bpy.ops.object.bake(type='EMIT')
        nt.links.new(b.outputs[0],output.inputs['Surface']);nt.nodes.remove(emission);nt.nodes.remove(mix);nt.nodes.remove(target)
        newcolor.filepath_raw=str(out/f'dragon_{group}_color.png');newcolor.file_format='PNG';newcolor.save();newcolor.pack();color.image=newcolor
        scene.render.bake.use_selected_to_active=True;scene.render.bake.use_clear=False
    for ob in sources.values():bpy.data.objects.remove(ob,do_unlink=True)
    scene.render.bake.use_selected_to_active=False;scene.render.bake.use_clear=True
    return reports

def undercoat(ob,material,flat,inner):
    """Keep hollow cavities, opening seats and inner ears non-emissive."""
    assignments=[]
    for p in ob.data.polygons:
        if ob.name=='Ears' and p.material_index==1:assignments.append(2)
        elif not exterior(p,ob) or guard(p.center,ob.name):assignments.append(1)
        else:assignments.append(0)
    ob.data.materials.clear()
    for m in (material,flat,inner):ob.data.materials.append(m)
    for p,index in zip(ob.data.polygons,assignments):p.material_index=index
    ob['dragonUndercoat']=True
