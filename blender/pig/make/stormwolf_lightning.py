"""Branching lightning geometry and a deterministic rapid flash timeline."""
import bpy,math,random,json
from pathlib import Path
from mathutils import Vector

EVENTS=[
 [(3,1),(4,0),(6,.55),(7,0),(11,1),(12,0),(34,1),(35,.45),(36,0),(53,1),(54,0)],
 [(11,1),(12,0),(14,.7),(15,0),(38,1),(39,0),(41,.5),(42,0)],
 [(11,.85),(12,0),(22,1),(23,0),(25,.5),(26,0),(44,1),(45,0)],
 [(6,1),(7,0),(11,.8),(12,0),(31,1),(32,.6),(33,0),(55,1),(56,0)],
 [(9,1),(10,0),(11,.65),(12,0),(27,.9),(28,0),(47,1),(48,0)],
 [(11,1),(12,0),(18,1),(19,0),(20,.4),(21,0),(50,1),(51,0)],
]

def values(frame):
    result=[]
    for events in EVENTS:
        value=0
        for at,next_value in events:
            if at<=frame:value=next_value
        result.append(value)
    return result

def constant_keys(datablock):
    action=datablock.animation_data.action
    # Blender 5 uses layered actions; all interpolation is stepped, never a
    # soft opacity fade between the brief flashes.
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points:point.interpolation='CONSTANT'

def build(body_tree,tail,out):
    buckets=[([],[]) for _ in range(6)]
    specs=[]
    def anchor(x,y):
        hit=body_tree.ray_cast(Vector((x,y,3)),Vector((0,0,-1)),5)
        assert hit[0] is not None,(x,y)
        return hit[0]+Vector((0,0,.005))
    for group,x,y,end in [
        (0,-.18,-.25,(-.67,-.1,1.88)),(1,.18,.08,(.83,.18,1.84)),
        (2,-.12,.44,(-.50,.89,1.96)),(3,.12,.65,(.47,1.05,1.78))]:
        specs.append((group,anchor(x,y),Vector(end),.050))
    for group,sign in ((4,-1),(5,1)):
        hit=body_tree.ray_cast(Vector((sign*3,.05,.35)),Vector((-sign,0,0)),5)
        assert hit[0] is not None
        specs.append((group,hit[0],Vector((sign*1.31,.15,1.00)),.042))
    coords=[v.co for v in tail.data.vertices];back=max(c.y for c in coords)
    tuft=[c for c in coords if c.y>back-.18]
    center=sum(tuft,Vector())/len(tuft)
    for group,sign in ((4,-1),(5,1)):
        start=max(tuft,key=lambda c: c.z+sign*.25*c.x).copy()
        specs.append((group,start,center+Vector((sign*.36,.35,.66)),.037))

    def jagged(start,end,seed,segments=9):
        rng=random.Random(seed);direction=end-start
        u=direction.cross(Vector((0,0,1)))
        if u.length<.01:u=direction.cross(Vector((1,0,0)))
        u.normalize();v=direction.normalized().cross(u).normalized()
        points=[]
        for i in range(segments+1):
            t=i/segments
            jitter=0 if i in (0,segments) else (1 if i%2 else -1)*rng.uniform(.035,.105)
            points.append(start+direction*t+u*jitter+v*rng.uniform(-.023,.023)*(0 if i in (0,segments) else 1))
        return points,u

    def stroke(group,points,width):
        verts,faces=buckets[group];base=len(verts)
        for i,p in enumerate(points):
            direction=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
            u=direction.cross(Vector((0,1,0)))
            if u.length<.05:u=direction.cross(Vector((1,0,0)))
            u.normalize();v=direction.cross(u).normalized()
            radius=width*(1-i/(len(points)-1)*.93)
            for j in range(4):verts.append(tuple(p+radius*(u*math.cos(j*math.pi/2)+v*math.sin(j*math.pi/2))))
        faces.append(tuple(base+j for j in reversed(range(4))))
        for i in range(len(points)-1):
            for j in range(4):faces.append((base+i*4+j,base+i*4+(j+1)%4,base+(i+1)*4+(j+1)%4,base+(i+1)*4+j))
        faces.append(tuple(base+(len(points)-1)*4+j for j in range(4)))
    for i,(group,start,end,width) in enumerate(specs):
        points,u=jagged(start,end,1700+i);stroke(group,points,width)
        branch_start=points[4]
        branch_end=points[7]+u*(.20 if i%2 else -.24)+Vector((0,0,-.08))
        branch,_=jagged(branch_start,branch_end,2200+i,5);stroke(group,branch,width*.65)
    objects=[]
    for group,(verts,faces) in enumerate(buckets):
        mesh=bpy.data.meshes.new(f'Lightning_p{group}');mesh.from_pydata(verts,[],faces);mesh.update()
        ob=bpy.data.objects.new(f'Lightning_p{group}',mesh);bpy.context.scene.collection.objects.link(ob)
        mat=bpy.data.materials.new(f'LightningFlash_{group}');mat.use_nodes=True
        nt=mat.node_tree;nt.nodes.clear();output=nt.nodes.new('ShaderNodeOutputMaterial');em=nt.nodes.new('ShaderNodeEmission')
        em.inputs['Color'].default_value=(.24,.78,1.0,1);nt.links.new(em.outputs[0],output.inputs['Surface'])
        ob.data.materials.append(mat)
        for frame in range(1,62):
            amount=values(1 if frame==61 else frame)[group]
            ob.hide_render=amount==0;ob.keyframe_insert('hide_render',frame=frame)
            ob.hide_viewport=amount==0;ob.keyframe_insert('hide_viewport',frame=frame)
            em.inputs['Strength'].default_value=amount*5;em.inputs['Strength'].keyframe_insert('default_value',frame=frame)
        constant_keys(ob);constant_keys(nt)
        ob['lightningGroup']=group;objects.append(ob)
    spec=dict(fps=30,frames=60,loopSeconds=2,mainBolts=8,forks=8,
        style='Long, chunky, tapered jagged bolts with substantial branching tips',
        mainBoltBaseDiameterStuds=.60,bodyGlow=dict(mask='stormwolf_body_emissive.png',idleStrength=.35,peakStrength=5.0,mode='Stepped brightness synchronized to strongest active bolt group'),
        interpolation='Instant on/off. Most flashes last one frame (33 ms); double strikes and quiet gaps vary per group.',
        groups=[dict(name=f'Lightning_p{i}',events=[dict(frame=f,strength=s) for f,s in events]) for i,events in enumerate(EVENTS)])
    (out/'lightning-animation.json').write_text(json.dumps(spec,indent=2))
    schedule='{\n'+',\n'.join('    {'+', '.join('{'+str(frame)+', '+str(strength)+'}' for frame,strength in events)+'}' for events in EVENTS)+'\n}'
    template=Path(__file__).with_name('stormwolf_lightning.template.luau').read_text()
    (out/'StormWolfLightning.luau').write_text(template.replace('__EVENTS__',schedule))
    return objects,spec

def compositor(scene):
    scene.use_nodes=True
    if hasattr(scene,'compositing_node_group'):
        nt=bpy.data.node_groups.new('StormWolf_LightningGlow','CompositorNodeTree');scene.compositing_node_group=nt
        nt.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');output=nt.nodes.new('NodeGroupOutput')
    else:
        nt=scene.node_tree;nt.nodes.clear();output=nt.nodes.new('CompositorNodeComposite')
    layer=nt.nodes.new('CompositorNodeRLayers');glow=nt.nodes.new('CompositorNodeGlare')
    if 'Type' in glow.inputs:
        glow.inputs['Type'].default_value='Fog Glow';glow.inputs['Quality'].default_value='High'
        glow.inputs['Size'].default_value=.20;glow.inputs['Strength'].default_value=.45
    else:glow.glare_type='FOG_GLOW';glow.quality='HIGH'
    if 'Threshold' in glow.inputs:glow.inputs['Threshold'].default_value=1.5
    elif hasattr(glow,'threshold'):glow.threshold=1.5
    if hasattr(glow,'size'):glow.size=7
    nt.links.new(layer.outputs['Image'],glow.inputs['Image']);nt.links.new(glow.outputs['Image'],output.inputs['Image'])
