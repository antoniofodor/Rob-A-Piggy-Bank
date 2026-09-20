"""Clean UV coat and stripe-only emission for the approved piggy reference.

Painted markings avoid overlapping raised shells. Each band has its own sparse
angular centerline, broad middle and sharp taper. Face: one inner and one outer
marking per eye. This does not edit the source pig's geometry.
"""
import math
import bpy
import numpy as np

def build_coat(body,material,out,rgb):
    size=2048
    u=(np.arange(size,dtype=np.float32)+.5)/size
    z=((np.arange(size,dtype=np.float32)+.5)/size*2-1)[:,None]
    angle=(np.minimum(u,1-u)*math.tau)[None,:]
    aa=2/size*1.5
    coat=np.empty((size,size,4),dtype=np.float32)
    coat[:,:,:3]=np.array(rgb['Coat'],dtype=np.float32)/255;coat[:,:,3]=1
    glow=np.zeros_like(coat);glow[:,:,3]=1

    def paint(coverage,tone):
        color=np.array(rgb[tone],dtype=np.float32)/255
        for channel in range(3):
            coat[:,:,channel]*=1-coverage
            coat[:,:,channel]+=coverage*color[channel]
            glow[:,:,channel]*=1-coverage
            glow[:,:,channel]+=coverage*color[channel]

    # Name, rear/front limits, unique sparse height profile, broad-middle width.
    bands=[
      ('Coral',.24,2.28,[.86,.82,.79,.72,.73,.69,.62],.052),
      ('Orange',.27,2.59,[.70,.65,.61,.57,.49,.32,.18],.096),
      ('Gold',.34,2.47,[.51,.46,.43,.33,.28,.055,-.14],.101),
      ('Lime',.43,2.36,[.30,.26,.20,.155,.045,-.19,-.36],.093),
      ('Cyan',.55,2.24,[.075,.035,-.025,-.145,-.12,-.37,-.50],.084),
      ('Blue',.68,2.10,[-.175,-.22,-.275,-.37,-.40,-.54,-.64],.065),
      ('Violet',.81,1.97,[-.39,-.435,-.50,-.565,-.61,-.69,-.755],.047)]
    knots=[0,.17,.36,.53,.69,.86,1]
    for index,(tone,start,end,heights,halfwidth) in enumerate(bands):
        t=(angle-start)/(end-start)
        center=np.interp(t.ravel(),knots,heights).reshape(1,-1)
        # Each tapered band grows from a fine rear point to a confident wide
        # middle. Sparse width changes form clean tiger markings, not teeth.
        profile=[0,.75,1.02,.92,1.00,.48,0]
        if index%2:profile=[0,.82,.91,1.05,.88,.42,0]
        width=np.interp(t.ravel(),knots,profile).reshape(1,-1)*halfwidth
        coverage=np.clip(.5+(width-np.abs(z-center))/aa,0,1)
        coverage*=((t>=0)&(t<=1))
        paint(coverage,tone)

    def polygon_coverage(points):
        inside=np.zeros((size,size),dtype=bool)
        distance=np.full((size,size),100,dtype=np.float32)
        for (ax,ay),(bx,by) in zip(points,points[1:]+points[:1]):
            if abs(by-ay)>1e-8:
                inside^=((ay>z)!=(by>z))&(angle<(bx-ax)*(z-ay)/(by-ay)+ax)
            dx=bx-ax;dy=by-ay
            t=np.clip(((angle-ax)*dx+(z-ay)*dy)/(dx*dx+dy*dy),0,1)
            distance=np.minimum(distance,np.sqrt((angle-ax-t*dx)**2+(z-ay-t*dy)**2))
        return np.clip(.5+np.where(inside,distance,-distance)/aa,0,1)

    # Outer mark descends beside the eye; single inner mark points inward
    # above the brow. No second stripe is stacked inside either eye.
    outer=[(2.30,.69),(2.40,.68),(2.49,.60),(2.55,.49),(2.67,.27),(2.53,.38),(2.40,.51)]
    inner=[(2.56,.795),(2.65,.80),(2.77,.72),(2.94,.565),(2.77,.64),(2.68,.665)]
    paint(polygon_coverage(outer),'Orange')
    coverage=polygon_coverage(inner)
    paint(coverage*(u[None,:]>.5),'Orange')
    paint(coverage*(u[None,:]<=.5),'Gold')

    def save_image(name,pixels):
        image=bpy.data.images.new(name,width=size,height=size,alpha=True)
        image.pixels.foreach_set(pixels.ravel())
        image.file_format='PNG';image.filepath_raw=str(out/name)
        image.save();image.pack()
        return image
    color=save_image('rainbowtiger-coat.png',coat)
    emission=save_image('rainbowtiger-stripe-emission.png',glow)

    # Cylindrical UVs put the seam behind the pig; repeat wrapping joins it.
    uv=body.data.uv_layers.new(name='TigerCoatUV')
    for face in body.data.polygons:
        values=[]
        for li in face.loop_indices:
            p=body.data.vertices[body.data.loops[li].vertex_index].co
            values.append(((math.atan2(p.x,p.y)/math.tau)%1,(p.z+1)/2))
        wrapped=max(v[0] for v in values)-min(v[0] for v in values)>.5
        for li,(uu,vv) in zip(face.loop_indices,values):
            uv.data[li].uv=(uu+1 if wrapped and uu<.5 else uu,vv)
    for old in list(body.data.uv_layers):
        if old.name!=uv.name:body.data.uv_layers.remove(old)
    body.data.uv_layers.active=uv;uv.active_render=True

    interior=material.copy();interior.name='RainbowTiger_Inside'
    body.data.materials.append(interior)
    for face in body.data.polygons:
        face.material_index=1 if face.normal.dot(face.center)<.25 else 0
    nodes=material.node_tree.nodes;links=material.node_tree.links
    uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map=uv.name
    for image,target in [(color,'Base Color'),(emission,'Emission Color')]:
        node=nodes.new('ShaderNodeTexImage');node.image=image;node.interpolation='Linear'
        node.extension='REPEAT';links.new(uvnode.outputs['UV'],node.inputs['Vector'])
        links.new(node.outputs['Color'],nodes['Principled BSDF'].inputs[target])
    body['colorTexture']='rainbowtiger-coat.png'
    body['emissionTexture']='rainbowtiger-stripe-emission.png'
    return {'resolution':size,'colorTexture':color.name,'emissionTexture':emission.name,
            'faceMarkings':'One inner and one outer stripe per eye','raisedStripeMeshes':0}
