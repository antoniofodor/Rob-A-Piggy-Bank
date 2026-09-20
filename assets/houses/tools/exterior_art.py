"""Exterior-only helpers. Blender X across, Y rearward, Z up; units intended as studs."""
import bpy
import math
import json
from mathutils import Vector
from house_art import HouseArt

class ExteriorArt(HouseArt):
    def prism(self,name,outline,front,back,mat):
        """Extrude an X/Z outline along Y; closed manifold decorative facade."""
        n=len(outline)
        vs=[(x,y,z) for y in (front,back) for x,z in outline]
        fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
        fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return self.tag(self.mesh(name,vs,fs,mat))

    def tube(self,name,p,radius,thickness,mat,normal=(0,0,1),segments=16):
        bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=6,
            major_radius=radius,minor_radius=thickness,location=p)
        o=bpy.context.object
        o.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler()
        return self.tag(self.keep(o,name,mat))

    def cylinder_art(self,name,p,radius,depth,mat,n=12,normal=(0,0,1)):
        return self.tag(self.cylinder(name,p,radius,depth,mat,n,normal))

    def rock(self,name,p,scale,mat,seed=0):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p)
        o=bpy.context.object
        for i,v in enumerate(o.data.vertices):
            factor=1+.12*math.sin(i*17.13+seed)
            v.co.x*=scale[0]*factor;v.co.y*=scale[1]*factor;v.co.z*=scale[2]*factor
        lowest=min(o.location.z+v.co.z for v in o.data.vertices)
        if lowest<.15:o.location.z+=.15-lowest
        return self.tag(self.keep(o,name,mat))

    def pointed(self,name,x,y,z,width,height,mat,depth=.2):
        return self.prism(name,[(x-width/2,z),(x+width/2,z),
            (x+width/2,z+height*.69),(x,z+height),(x-width/2,z+height*.69)],y-depth/2,y+depth/2,mat)

    def pointed_window(self,name,x,y,z,width,height,frame,glass):
        self.pointed(name+'_Shadow',x,y+.03,z-.22,width+.64,height+.53,'Ink',.18)
        self.pointed(name+'_Frame',x,y-.09,z-.1,width+.34,height+.27,frame,.24)
        self.pointed(name+'_Pane',x,y-.24,z+.06,width-.22,height-.13,glass,.13)
        self.box(name+'_Mullion',(x,y-.34,z+height*.4),(.12,.12,height*.79),frame,.02)
        self.box(name+'_Crossbar',(x,y-.34,z+height*.34),(width-.15,.12,.14),frame,.02)
        self.box(name+'_Sill',(x,y-.21,z-.14),(width+.72,.7,.28),frame,.05)

    def glow(self,name,strength):
        node=self.mat[name].node_tree.nodes['Principled BSDF']
        node.inputs['Emission Color'].default_value=self.mat[name].diffuse_color
        node.inputs['Emission Strength'].default_value=strength

    def complete(self,reference,look,camera,scale,fx,draft=False):
        # Keep source geometry editable; merge by section, then material-split for import later.
        source_objects=len(self.visual)
        self.merge_sections()
        report=self.export_art({'reference':reference,'status':'MVP exterior asset draft; no interior or Studio integration',
            'authoredObjectsBeforeMerge':source_objects,'routesBlender':[],
            'coordinateMapping':'Blender (x,y,z) -> Roblox FBX/OBJ (-x,z,y)',
            'frontWallBlenderY':0,'interiors':'explicitly deferred; door is closed decorative geometry',
            'collision':'No collision draft supplied; integrator must choose exterior collision and validate plot fit',
            'fx':fx})
        (self.out/'animation-handoff.json').write_text(json.dumps({'status':'Named mesh groups and timing spec; runtime animation not installed','effects':fx},indent=2))
        self.stage(look,scale,camera,draft)
        self.scene.render.resolution_x=1200
        self.scene.render.resolution_y=1200
        self.scene.cycles.samples=24 if draft else 40
        # Preview emission is visual guidance only. The export script strips emission.
        self.render_view('exterior.png')
        self.render_view('front.png',(0,-90,look[2]),look,scale)
        self.render_view('road.png',(0,-70,5),(0,9,19),scale+5)
        self.save_source()
        return report
