"""Arcade accessory geometry and closed six-second animation loops."""
def linear_keys(ob):
    if ob.animation_data:
        action=ob.animation_data.action
        for slot in action.slots:
            for layer in action.layers:
                for strip in layer.strips:
                    bag=strip.channelbag(slot)
                    if bag:
                        for curve in bag.fcurves:
                            for point in curve.keyframe_points:point.interpolation='LINEAR'

def box_mesh(name,center,dimensions,material,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    ob=bpy.context.object;ob.name=name;ob.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    move(ob,fxcol);assign(ob,material);extras.append(ob)
    if bevel:
        mod=ob.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob

if KEY=='respawn':
    # Small cubes are actual accessories; the body squares remain flat artwork.
    for j in range(7):
        side=-1 if j%2 else 1
        pos=Vector((side*(.72+.10*(j%3)),.63+.035*j,.25+.13*j))
        ob=box_mesh('RespawnPixel_'+str(j),pos,(.105,.105,.105),flat('Pixel'+str(j),P[1 if j%3 else 3],1.4))
        for frame in (1,19,37,55,73,91,109,127,145):
            t=((frame-1)/144+j/7)%1
            ob.location=pos+Vector((side*.12*math.sin(t*math.pi),.08*math.sin(t*math.pi),t*.38))
            # At wrap the cube has disappeared, avoiding a visible teleport.
            size=max(.015,math.sin(math.pi*t))
            ob.scale=(size,size,size)
            ob.keyframe_insert(data_path='location',frame=frame);ob.keyframe_insert(data_path='scale',frame=frame)
        ob['motion']='rise and dissolve';linear_keys(ob)

if KEY=='jackpot':
    brass=flat('Brass',[197,137,41],metal=.66,rough=.3)
    dark=flat('Housing enamel',[96,28,48],metal=.12,rough=.4)
    amber=flat('Amber bulbs',[255,176,40],1.7,rough=.3)
    cream=flat('Reel end caps',[222,199,144],metal=.1,rough=.55)
    # A curved saddle follows the actual body, burying its underside slightly.
    verts=[];nx,ny=10,8
    for layer in (0,1):
        for iy in range(ny+1):
            yy=-.09+.69*iy/ny
            for ix in range(nx+1):
                xx=-.56+1.12*ix/nx
                hit,co,normal,_=parts['Body'].ray_cast(Vector((xx,yy,3)),Vector((0,0,-1)));assert hit
                zz=co.z-.025 if layer==0 else co.z+.055
                verts.append((xx,yy,zz))
    faces=[];offset=(nx+1)*(ny+1)
    for layer in (0,1):
        for iy in range(ny):
            for ix in range(nx):
                k=layer*offset+iy*(nx+1)+ix
                face=(k,k+1,k+nx+2,k+nx+1);faces.append(face if layer else tuple(reversed(face)))
    boundary=list(range(nx+1))+[iy*(nx+1)+nx for iy in range(1,ny+1)]+[ny*(nx+1)+ix for ix in range(nx-1,-1,-1)]+[iy*(nx+1) for iy in range(ny-1,0,-1)]
    for i,k in enumerate(boundary):
        j=boundary[(i+1)%len(boundary)];faces.append((k,j,j+offset,k+offset))
    saddle=mesh('ReelSaddle',verts,faces,brass);saddle['attachment']='thin curved saddle follows Body with .025 source-unit embed'
    for xs in (-.50,.50):
        for ys in (-.025,.53):
            hit,co,normal,_=parts['Body'].ray_cast(Vector((xs,ys,3)),Vector((0,0,-1)));assert hit
            top=.94;bottom=co.z+.025
            box_mesh('SaddleSupport_'+str(xs)+'_'+str(ys),(xs,ys,(top+bottom)/2),(.08,.09,top-bottom),brass,.012)
    box_mesh('RearHousing',(0,.64,1.15),(1.18,.09,.55),dark,.035)
    box_mesh('FrontSill',(0,-.035,.925),(1.19,.10,.10),brass,.023)
    box_mesh('UpperRail',(0,.27,1.515),(1.19,.10,.065),brass,.018)
    for xside in (-.585,.585):
        box_mesh('ReelSide_'+str(xside),(xside,.29,1.19),(.075,.64,.59),brass,.055)

    def polygon_mask(xx,yy,points):
        inside=np.zeros(xx.shape,dtype=bool)
        for i in range(len(points)):
            x1,y1=points[i];x2,y2=points[i-1]
            inside^=((y1>yy)!=(y2>yy))&(xx<(x2-x1)*(yy-y1)/(y2-y1+1e-12)+x1)
        return inside

    def reel_material(j):
        w,h=256,1024;yy,xx=np.mgrid[0:h,0:w];u=xx/(w-1);v=yy/(h-1)
        pix=np.ones((h,w,4),dtype=np.float32);pix[:,:,:3]=lin((247,229,183))
        pix[(u<.035)|(u>.965),:3]=lin((181,130,48))
        for k in range(4):
            cy=(k+.5)/4;ax=(u-.5)/.40;ay=(cy-v)/.085
            symbol=(j+k)%3
            if symbol==0:
                pts=[((.93 if n%2==0 else .42)*math.cos(math.pi/2+n*math.pi/5),(.93 if n%2==0 else .42)*math.sin(math.pi/2+n*math.pi/5)) for n in range(10)]
                outer=polygon_mask(ax,ay,pts);inner=polygon_mask(ax*1.2,ay*1.2,pts)
                pix[outer,:3]=lin((154,86,18));pix[inner,:3]=lin((246,178,35))
            elif symbol==1:
                stem=(np.abs(ax+.14*ay)<.08)&(ay>.05)&(ay<.9)
                leaf=((ax-.3)/.38)**2+((ay-.72)/.16)**2<1
                fruit=((ax+.30)**2+(ay+.25)**2<.24)|((ax-.31)**2+(ay+.25)**2<.24)
                pix[stem|leaf,:3]=lin((48,110,48));pix[fruit,:3]=lin((205,35,56))
                shine=((ax+.40)**2+(ay+.09)**2<.014)|((ax-.21)**2+(ay+.09)**2<.014)
                pix[shine,:3]=lin((255,128,129))
            else:
                d=np.abs(ax)+np.abs(ay)*.78
                pix[d<.86,:3]=lin((134,26,49));pix[d<.66,:3]=lin((224,49,70))
                pix[(d<.66)&(ax<0),:3]=lin((249,105,109))
        im=bpy.data.images.new(f'ReelSymbols_{j}',w,h,alpha=True);im.pixels.foreach_set(pix.ravel())
        path=HOME/'sheets'/f'jackpot_arcade_v1_reel_{j}.png';im.filepath_raw=str(path);im.file_format='PNG';im.save();im.pack()
        mat=flat(f'ReelPrinted_{j}',(240,220,175),rough=.72)
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im
        mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        return mat

    for j,xc in enumerate((-.36,0,.36)):
        # Cylinder axis X; local UVs wind around its circumference.
        count=48;radius=.28;width=.325;verts=[]
        for xend in (-width/2,width/2):
            for i in range(count):
                a=i*math.tau/count;verts.append((xend,radius*math.cos(a),radius*math.sin(a)))
        faces=[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
        faces.extend([tuple(reversed(range(count))),tuple(range(count,count*2))])
        reel=mesh('SymbolReel_'+str(j),verts,faces,reel_material(j));reel.location=(xc,.29,1.205)
        reel.data.materials.append(cream)
        uv=reel.data.uv_layers.new(name='ReelUV')
        for poly in reel.data.polygons:
            if poly.index<count:
                i=poly.index
                for li,value in zip(poly.loop_indices,[(0,i/count),(0,(i+1)/count),(1,(i+1)/count),(1,i/count)]):uv.data[li].uv=value
                poly.use_smooth=True
            else:
                poly.material_index=1
        for frame,angle in [(1,math.pi/4),(145,math.pi/4+math.tau*(j+1))]:
            reel.rotation_euler.x=angle;reel.keyframe_insert(data_path='rotation_euler',frame=frame)
        reel['motion']='reel spin';reel['periodSeconds']=6/(j+1);linear_keys(reel)
    for side in (-1,1):
        for j in range(5):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=.038,location=(side*.63,-.042,.98+j*.115))
            ob=bpy.context.object;ob.name=f'Bulb_{side}_{j}';move(ob,fxcol);assign(ob,amber);extras.append(ob)
    tokenmat=flat('Token gold',[238,178,59],metal=.65,rough=.27)
    emblem=flat('Token emboss',[255,216,112],metal=.55,rough=.31)
    for j in range(6):
        side=-1 if j%2 else 1
        origin=Vector((side*(1.17+.09*(j%2)),.30+.18*(j//2),-.10+.23*(j//2)))
        bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.112,depth=.033,location=origin,rotation=(math.pi/2,0,.14*side))
        ob=bpy.context.object;ob.name='GoldToken_'+str(j);move(ob,fxcol);assign(ob,tokenmat);extras.append(ob)
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
        # Raised five-point motif joined to the coin; disconnected closed shells are valid.
        points=[]
        for depth in (-.026,-.019):
            for k in range(10):
                a=math.pi/2+k*math.pi/5;r=.063 if k%2==0 else .029
                points.append((r*math.cos(a),depth,r*math.sin(a)))
        faces=[tuple(reversed(range(10))),tuple(range(10,20))]+[(k,(k+1)%10,(k+1)%10+10,k+10) for k in range(10)]
        badge=mesh('TokenBadge_'+str(j),points,faces,emblem);badge.location=origin
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);badge.select_set(True);bpy.context.view_layer.objects.active=ob
        bpy.ops.object.join();extras.remove(badge)
        for frame in (1,19,37,55,73,91,109,127,145):
            a=(frame-1)/144*math.tau+j*math.tau/6
            ob.location=origin+Vector((side*.09*math.sin(a),.09*math.cos(a),.11*math.sin(a)))
            ob.rotation_euler.z=.24*math.sin(a)
            ob.keyframe_insert(data_path='location',frame=frame);ob.keyframe_insert(data_path='rotation_euler',frame=frame)
        ob['motion']='rear token orbit';ob['periodSeconds']=6

# Separate small visual proxies for proposed runtime emitters.
if TIER!='rare':
    for j in range(10):
        side=-1 if j%2 else 1;pos=(side*(.91+.04*(j%4)),.6+.04*(j%3),.10+.13*j)
        bpy.ops.mesh.primitive_cube_add(size=.022 if KEY=='respawn' else .014,location=pos)
        ob=bpy.context.object;ob.name='AuraPixel_'+str(j);move(ob,auracol)
        assign(ob,flat(ob.name,P[1] if KEY=='respawn' else P[-1],1.7));aura.append(ob);loop_bob(ob,.10,j*.6)
