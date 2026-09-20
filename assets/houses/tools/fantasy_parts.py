"""Shared exterior-only construction vocabulary for the remaining fantasy houses."""
import bpy,math
from mathutils import Vector,Matrix
from exterior_art import ExteriorArt

BASE={
 'Ink':(29,27,37),'Stone':(162,164,176),'Cream':(235,218,181),'Timber':(98,68,40),
 'Gold':(214,163,65),'Amber':(250,177,57),'DarkGlass':(31,43,70),'Leaf':(61,107,61),
 'Violet':(96,38,163),'Teal':(33,113,130),'Pink':(207,70,118),'Blue':(57,113,191),
}

class FantasyArt(ExteriorArt):
    def cone(self,name,p,r1,r2,depth,mat,n=8):
        bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r1,radius2=r2,depth=depth,location=p)
        return self.tag(self.keep(bpy.context.object,name,mat))

    def gem(self,name,p,r,h,mat):
        x,y,z=p
        vs=[(x,y,z-h/2),(x+r,y,z),(x,y+r*.55,z),(x-r,y,z),(x,y-r*.55,z),(x,y,z+h/2)]
        fs=[(0,2,1),(0,3,2),(0,4,3),(0,1,4),(5,1,2),(5,2,3),(5,3,4),(5,4,1)]
        return self.tag(self.mesh(name,vs,fs,mat))

    def base(self,w,d,mat='Stone',y=None,top=.8):
        self.section='Foundation'
        return self.box('Dressed foundation',(0,y if y is not None else d/2-2,top/2),(w,d,top),mat,.3)

    def disc(self,name,x,y,z,rx,rz,depth,mat):
        outline=[(x+rx*math.cos(i*math.tau/24),z+rz*math.sin(i*math.tau/24)) for i in range(24)]
        return self.prism(name,outline,y-depth/2,y+depth/2,mat)

    def round_window(self,name,p,r,frame='Gold',glass='DarkGlass',normal=(0,-1,0)):
        p=Vector(p);n=Vector(normal).normalized()
        self.cylinder_art(name+'_Pane',p,r,.17,glass,20,n)
        self.tube(name+'_Frame',p+n*.13,r+.12,.15,frame,n,20)
        tangent=Vector((n.y,-n.x,0))
        self.rod(name+'_Vertical',p+n*.23+Vector((0,0,-r)),p+n*.23+Vector((0,0,r)),.07,frame)
        self.rod(name+'_Cross',p+n*.23-tangent*r,p+n*.23+tangent*r,.07,frame)

    def door(self,x=0,y=-.35,z=.9,w=4.8,h=7,frame='Stone',panel='Timber'):
        self.section='Entrance'
        self.arch_shape('Door surround',w+.7,z+h-w/2,z-.1,.35,frame,(x,y,0))
        self.arch_shape('Closed door',w,z+h-w/2-.05,z+.07,.18,panel,(x,y-.27,0))
        for dx in (-.3,0,.3):self.box('Door board seam',(x+dx*w,y-.4,z+h*.4),(.035,.04,h*.76),'Ink',0)
        self.tube('Door handle',(x+w*.28,y-.47,z+h*.37),.18,.045,'Gold',(0,-1,0),10)

    def steps(self,width=6,count=4,rise=.3,tread=.9,y=-.5,mat='Stone'):
        self.section='Approach'
        for i in range(count):
            top=(i+1)*rise
            self.box('Fixed approach step '+str(i),(0,y-(count-1-i)*tread,top/2),(width,tread+.06,top),mat,.04)

    def lantern(self,name,p,mat='Amber',scale=1,section='Lanterns'):
        x,y,z=p;self.section=section
        self.ellipsoid(name+'_Glow',(x,y,z),(.42*scale,.42*scale,.56*scale),mat,False)
        self.section='LanternFrames'
        self.cone(name+'_Roof',(x,y,z+.67*scale),.64*scale,.18*scale,.35*scale,'Timber',6)
        self.cylinder_art(name+'_Base',(x,y,z-.58*scale),.47*scale,.16*scale,'Timber',6)
        for i in range(4):
            an=i*math.tau/4+math.pi/4;dx=.4*math.cos(an)*scale;dy=.4*math.sin(an)*scale
            self.rod(name+'_Frame',(x+dx,y+dy,z-.52*scale),(x+dx,y+dy,z+.51*scale),.04*scale,'Gold')

    def roof(self,name,x,y,w,d,eave,rise,mat,trim,rows=6,bowed=False):
        """Solid roof and individually pitched flat tiles; ridge runs along Y."""
        self.section=name
        def height(xx):
            t=abs(xx-x)/(w/2)
            return eave+rise*(1-t)+(.5*math.sin((xx-x)*.3) if bowed else 0)
        outline=[(x-w/2,eave-.35),(x+w/2,eave-.35),(x+w/2,height(x+w/2)),(x,height(x)),(x-w/2,height(x-w/2))]
        self.prism(name+'_Solid',outline,y-d/2,y+d/2,mat)
        for side in (-1,1):
            for i in range(rows):
                x1=x+side*w/2*i/rows;x2=x+side*w/2*(i+1)/rows
                z1,z2=height(x1)+.12,height(x2)+.12
                length=math.hypot(x2-x1,z2-z1)
                for j in range(4):
                    obj=self.box(name+'_Tile',((x1+x2)/2,y-d/2+(j+.5)*d/4,(z1+z2)/2),(length+.08,d/4-.04,.22),mat,.025)
                    obj.rotation_euler.y=-math.atan2(z2-z1,x2-x1)
        for yy in (y-d/2-.12,y+d/2+.12):
            for side in (-1,1):self.rod(name+'_Gable edge',(x,yy,height(x)+.18),(x+side*w/2,yy,height(x+side*w/2)+.18),.22,trim)
        self.box(name+'_Ridge',(x,y,height(x)+.26),(.5,d+.6,.4),trim,.06)

    def oct_tower(self,name,x,y,z,r,h,wall,trim,roof,point=7):
        self.section=name
        self.cylinder_art(name+'_Body',(x,y,z+h/2),r,h,wall,8)
        for zz in (z+.4,z+h*.5,z+h):
            self.cylinder_art(name+'_Course',(x,y,zz),r+.4,.6,trim,8)
        self.cone(name+'_Roof',(x,y,z+h+point*.42),r+.65,r*.32,point*.84,roof,8)
        self.cone(name+'_Finial',(x,y,z+h+point*.9),r*.36,0,point*.45,trim,8)
        for side in (-1,1):
            self.box(name+'_Corner',(x+side*r*.71,y-r*.71,z+h/2),(.3,.3,h),trim,.05)
        self.pointed_window(name+'_Upper',x,y-r-.1,z+h*.63,1.5,h*.19,trim,'DarkGlass')
        self.pointed_window(name+'_Lower',x,y-r-.12,z+1.5,1.6,min(5,h*.25),trim,'Amber')

    def star(self,name,x,y,z,r,mat):
        points=[(x+(r if i%2==0 else r*.28)*math.cos(i*math.pi/4),z+(r if i%2==0 else r*.28)*math.sin(i*math.pi/4)) for i in range(8)]
        return self.prism(name,points,y-.04,y+.04,mat)

    def transformed_group(self,items,matrix):
        bpy.context.view_layer.update()
        for o in items:o.matrix_world=matrix@o.matrix_world

    def finish(self,reference,look,camera,scale,fx):
        self.glow('Amber',.65)
        return self.complete(reference,look,camera,scale,fx,False)
