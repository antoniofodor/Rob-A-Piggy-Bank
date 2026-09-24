"""Six expansion piggies: simple epic motifs and visibly articulated legendary armor."""
def pivot_sway(ob,axis,amount,phase=0):
    start=ob.rotation_euler.copy()
    for f in (1,19,37,55,73,91,109,127,145):
        ob.rotation_euler=start.copy();ob.rotation_euler[axis]+=amount*math.sin((f-1)/144*math.tau+phase)
        ob.keyframe_insert(data_path='rotation_euler',frame=f)
    ob['motion']='hinged guard sway';ob['periodSeconds']=6

def shell_plate(name,side,cy,cz,half_y,half_z,material,thickness=.11):
    # Side armor is a closed convex polygon, buried at its central root.
    profile=[(-.82,-1),(.48,-1),(1,-.35),(.84,.76),(-.18,1),(-1,.35)]
    direction=Vector((side,cy,cz)).normalized()
    hit,point,normal,_=parts['Body'].ray_cast(direction*4,-direction);assert hit
    center=Vector((side*(abs(point.x)-.025),cy,cz))
    verts=[]
    for depth in (-.035,thickness):
        for u,v in profile:verts.append((side*depth,u*half_y,v*half_z))
    count=len(profile);faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    ob=mesh(name,verts,faces,material);ob.location=center;return ob

if KEY=='powerup':
    # The large arrows are paint; six restrained energy squares are the only extra geometry.
    for j in range(6):
        side=-1 if j%2 else 1
        ob=box_mesh('PowerSpark_'+str(j),(side*(1.02+.05*(j%3)),.48+.10*(j//2),.1+.22*(j//2)),(.055,.055,.055),flat('Spark'+str(j),P[1],1.2))
        loop_bob(ob,.12,j*.8)

if KEY=='finalboss':
    armor=flat('Boss armor',[88,43,105],metal=.22,rough=.4)
    gold=flat('Boss brass',[188,116,59],metal=.55,rough=.35)
    glow=flat('Boss energy',P[1],1.1)
    for side in (-1,1):
        for j,(cy,cz,hy,hz) in enumerate([(-.05,.25,.32,.32),(.43,.04,.33,.35)]):
            ob=shell_plate(f'BossGuard_{side}_{j}',side,cy,cz,hy,hz,gold)
            pivot_sway(ob,0,.045,j)
            # Insets and trim parent to the guard, so every layer moves together.
            inset=shell_plate(f'BossInset_{side}_{j}',side,cy,cz,hy*.84,hz*.84,armor,.10)
            inset.parent=ob;inset.location=(side*.045,0,0)
            jewel=crystal(f'OrbitPrism_Boss_{side}_{j}',(side*.15,0,.03),(side*.085,0,0),.12,glow,4)
            jewel.parent=ob;jewel.location=(0,0,0)
            bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.075,depth=.065,rotation=(0,math.pi/2,0))
            hinge=bpy.context.object;hinge.name=f'BossHinge_{side}_{j}';move(hinge,fxcol);assign(hinge,gold);extras.append(hinge)
            hinge.parent=ob;hinge.location=(side*.16,hy*.7,hz*.50)
        for j in range(3):
            cube=box_mesh(f'BossEnergy_{side}_{j}',(side*(1.22+.02*j),.48+.19*j,.10+.20*j),(.11,.11,.11),glow,.008)
            loop_bob(cube,.09,j+side)

if KEY=='mechaplayer':
    steel=flat('Mecha steel',[169,188,201],metal=.55,rough=.35)
    navy=flat('Mecha blue',[34,55,82],metal=.3,rough=.43)
    cyan=flat('Mecha vents',P[1],1.3)
    orange=flat('Warning orange',P[3],rough=.6)
    for side in (-1,1):
        for j,yy in enumerate((-.48,.54)):
            # Closed annular cuff sits around the original short leg.
            center=Vector((side*.5,yy,-.82));verts=[];n=12
            for zz,rr in [(-.19,.255),(.13,.255),(.13,.202),(-.19,.202)]:
                for i in range(n):
                    a=i*math.tau/n;verts.append((rr*math.cos(a),rr*math.sin(a),zz))
            faces=[]
            for ring in range(4):
                nxt=(ring+1)%4
                for i in range(n):faces.append((ring*n+i,ring*n+(i+1)%n,nxt*n+(i+1)%n,nxt*n+i))
            cuff=mesh(f'MechBoot_{side}_{j}',verts,faces,steel);cuff.location=center
            band=box_mesh(f'BootSignal_{side}_{j}',(side*.762,yy,-.79),(.027,.18,.045),cyan,.006)
        guard=shell_plate('MechGuard_'+str(side),side,.12,.06,.30,.27,navy,.13);pivot_sway(guard,1,.04,side)
        joint=box_mesh('MechGuardInset_'+str(side),(0,0,0),(.027,.20,.09),steel,.02);joint.parent=guard;joint.location=(side*.14,0,0)
        stripe=box_mesh('MechWarning_'+str(side),(0,0,0),(.03,.18,.026),orange,.005);stripe.parent=guard;stripe.location=(side*.16,0,.10)
        # Cylinder axis points rearward, firmly seated in a bracket at the rump.
        mount=box_mesh('ThrusterBracket_'+str(side),(side*.50,.78,.28),(.32,.33,.38),navy,.045)
        bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.20,depth=.40,location=(side*.50,1.0,.30),rotation=(math.pi/2,0,0))
        housing=bpy.context.object;housing.name='ThrusterHousing_'+str(side);move(housing,fxcol);assign(housing,steel);extras.append(housing)
        for j in range(3):
            vent=box_mesh(f'ThrusterVent_{side}_{j}',(side*.50,1.213,.20+j*.10),(.24,.025,.032),cyan,.005)
            loop_bob(vent,.012,j*.6)
        bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.13,radius2=.025,depth=.28,location=(side*.50,1.37,.30),rotation=(-math.pi/2,0,0))
        flame=bpy.context.object;flame.name='ThrusterPlume_'+str(side);move(flame,fxcol);assign(flame,cyan);extras.append(flame)
        for f in (1,37,73,109,145):
            flame.scale.z=.75+.25*math.cos((f-1)/144*math.tau)
            flame.keyframe_insert(data_path='scale',frame=f)
        flame['motion']='thruster pulse'
