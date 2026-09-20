"""Shared geometry helpers for reference-led house art, without runtime code."""
import bpy,bmesh,math,json,random
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
from collections import defaultdict
from mathutils import Vector,Matrix
from asset_common import Asset,ROOT

class HouseArt(Asset):
    def __init__(self,slug,revision,palette):
        super().__init__(slug,palette)
        self.out=ROOT/'assets/houses'/f'{house_slug(slug)}-v{revision}'
        self.out.mkdir(parents=True,exist_ok=True)
        self.revision=revision;self.section='Shell';self.hide_cut=False
        self.preview=False;self.smooth=False;self.rng=random.Random(92)

    def tag(self,o):
        o['section']=self.section;o['hide_cut']=self.hide_cut;o['preview']=self.preview
        for p in o.data.polygons:p.use_smooth=self.smooth
        return o

    def box(self,name,p,size,mat,bevel=.08,rot=0):
        x,y,z=(v/2 for v in size)
        vs=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        o=self.tag(self.mesh(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat))
        o.location=p;o.rotation_euler.z=rot
        if bevel:self.bevel(o,min(bevel,min(size)*.35),2)
        return o

    def bevel(self,o,width=.15,segments=2):
        bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.bevel(bm,geom=list(bm.edges),offset=width,segments=segments,affect='EDGES')
        bm.to_mesh(o.data);bm.free()
        return o

    def ellipsoid(self,name,p,scale,mat,smooth=True):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,radius=1,location=p)
        o=bpy.context.object;o.scale=scale
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        self.tag(self.keep(o,name,mat))
        for f in o.data.polygons:f.use_smooth=smooth
        return o

    def rod(self,name,p,q,r,mat):
        return self.tag(super().beam(name,p,q,r,mat))

    def arch_shape(self,name,width,spring,bottom,depth,mat,p=(0,0,0),angle=0):
        o=self.tag(self.arch(name,(0,0),width,spring,depth,bottom,mat))
        o.location=p;o.rotation_euler.z=angle
        return o

    def join(self,items,name):
        bpy.ops.object.select_all(action='DESELECT')
        for o in items:o.select_set(True)
        bpy.context.view_layer.objects.active=items[0]
        if len(items)>1:bpy.ops.object.join()
        result=bpy.context.object;result.name=name
        self.visual=[o for o in self.visual if o not in items]+[result]
        return result

    def fuse(self,items,name,voxel=.2,budget=9000,smooth=True):
        o=self.join(items,name);bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('Continuous sculpted volume','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Goo surface relaxation','SMOOTH');mod.factor=1;mod.iterations=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        o.data.calc_loop_triangles();n=len(o.data.loop_triangles)
        if n>budget:
            mod=o.modifiers.new('Game art topology','DECIMATE');mod.ratio=budget/n
            bpy.ops.object.modifier_apply(modifier=mod.name)
        for f in o.data.polygons:f.use_smooth=smooth
        return o

    def droplet(self,name,x,y,top,length,r,mat):
        # Broad attachment, narrow neck, rounded heavy hanging end.
        profile=[(0,r*.9),(.15,r),(.35,r*.78),(.6,r*.72),(.78,r*.82),(.91,r*.57),(.99,r*.13)]
        vs=[];n=12
        for t,rad in profile:
            for i in range(n):
                ang=i*math.tau/n
                vs.append((x+rad*math.cos(ang),y+rad*math.sin(ang),top-t*length))
        fs=[tuple(range(n-1,-1,-1)),tuple(range((len(profile)-1)*n,len(profile)*n))]
        for j in range(len(profile)-1):
            for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
        o=self.tag(self.mesh(name,vs,fs,mat))
        for f in o.data.polygons:f.use_smooth=True
        return o

    def rounded_outline(self,w,d,r,sub=8):
        points=[]
        for cx,cy,start in ((w/2-r,-d/2+r,-math.pi/2),(w/2-r,d/2-r,0),(-w/2+r,d/2-r,math.pi/2),(-w/2+r,-d/2+r,math.pi)):
            for i in range(sub+1):
                t=start+i*math.pi/(2*sub)
                points.append((cx+r*math.cos(t),cy+r*math.sin(t)))
        # Subdivide straight runs so the melted wall can bulge along them.
        expanded=[]
        for p,q in zip(points,points[1:]+points[:1]):
            n=max(1,math.ceil(math.dist(p,q)/2))
            expanded.extend((p[0]+(q[0]-p[0])*i/n,p[1]+(q[1]-p[1])*i/n) for i in range(n))
        return expanded

    def merge_sections(self):
        groups=defaultdict(list)
        for o in self.visual:groups[(o['section'],o['hide_cut'],o['preview'])].append(o)
        for (section,hide,preview),items in groups.items():
            chunks=[];chunk=[];n=0
            for o in items:
                o.data.calc_loop_triangles();count=len(o.data.loop_triangles)
                if n+count>15000 and chunk:chunks.append(chunk);chunk=[];n=0
                chunk.append(o);n+=count
            if chunk:chunks.append(chunk)
            for i,chunk in enumerate(chunks):
                self.join(chunk,('REVIEW_' if preview else '')+section+('_Cutaway' if hide else '')+f'_{i+1:02d}')

    def export_art(self,meta):
        bpy.context.view_layer.update();stats=[];points=[]
        bpy.ops.object.select_all(action='DESELECT')
        for o in self.visual:
            if o['preview']:continue
            o.select_set(True);bpy.context.view_layer.objects.active=o
            mod=o.modifiers.new('Export triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
            bm=bmesh.new();bm.from_mesh(o.data)
            stats.append({'name':o.name,'triangles':len(o.data.polygons),'nonManifoldEdges':sum(not e.is_manifold for e in bm.edges)})
            bm.free();points.extend(o.matrix_world@v.co for v in o.data.vertices)
        lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
        assert all(s['nonManifoldEdges']==0 and s['triangles']<20000 for s in stats),stats
        assert hi[0]-lo[0]<=60 and hi[1]-lo[1]<=57,(lo,hi)
        bpy.ops.export_scene.fbx(filepath=str(self.out/f'{house_slug(self.slug)}-visual.fbx'),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
        bpy.ops.wm.obj_export(filepath=str(self.out/f'{house_slug(self.slug)}-visual.obj'),export_selected_objects=True,forward_axis='Z',up_axis='Y',export_materials=True)
        report={'id':self.slug,'revision':self.revision,'visualMeshes':len(stats),'triangles':sum(s['triangles'] for s in stats),'meshes':stats,'boundsBlender':{'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]},'paletteRGB':self.palette,'collisionBoxesDraft':self.colliders,'mountsBlender':self.mounts,'mountYawBlender':self.mountYaw,**meta}
        (self.out/'geometry-report.json').write_text(json.dumps(report,indent=2))
        print('GEOMETRY_REPORT '+json.dumps({k:report[k] for k in ('visualMeshes','triangles','boundsBlender')}),flush=True)
        return report

    def stage(self,look,scale,camera,draft=False):
        self.scene.cycles.samples=24 if draft else 48
        self.scene.render.resolution_x=self.scene.render.resolution_y=1000 if draft else 1600
        self.scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.95,.96,.9,1)
        self.scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
        self.scene.view_settings.exposure=.25
        mat=bpy.data.materials.new('REVIEW warm backdrop');mat.use_nodes=True
        mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.92,.86,.73,1)
        bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.22));o=bpy.context.object;o.name='REVIEW_Ground';o.data.materials.append(mat)
        for name,p,power,size,color in [('Key',(-25,-35,45),13500,22,(1,.9,.72)),('Fill',(35,-15,30),6000,18,(.8,.9,1)),('Rim',(10,35,45),18000,18,(1,1,.9))]:
            data=bpy.data.lights.new('REVIEW_'+name,'AREA');o=bpy.data.objects.new(data.name,data);self.scene.collection.objects.link(o);o.location=p;data.energy=power;data.size=size;data.color=color;o.rotation_euler=(Vector(look)-o.location).to_track_quat('-Z','Y').to_euler()
        data=bpy.data.cameras.new('REVIEW_Camera');self.camera=bpy.data.objects.new(data.name,data);self.scene.collection.objects.link(self.camera);self.scene.camera=self.camera;data.type='ORTHO';data.ortho_scale=scale
        self.look=look;self.hero_camera=camera;self.hero_scale=scale

    def render_view(self,name,p=None,target=None,scale=None):
        self.camera.location=p or self.hero_camera
        self.camera.rotation_euler=(Vector(target or self.look)-self.camera.location).to_track_quat('-Z','Y').to_euler()
        self.camera.data.ortho_scale=scale or self.hero_scale
        self.scene.render.filepath=str(self.out/name);bpy.ops.render.render(write_still=True)

    def save_source(self):
        self.camera.location=self.hero_camera
        self.camera.rotation_euler=(Vector(self.look)-self.camera.location).to_track_quat('-Z','Y').to_euler()
        self.camera.data.ortho_scale=self.hero_scale
        bpy.ops.wm.save_as_mainfile(filepath=str(self.out/f'{house_slug(self.slug)}.blend'))
