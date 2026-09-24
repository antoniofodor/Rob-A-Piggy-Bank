"""Restrained, embedded stone accents. FX aura proxies are not export meshes."""
if KEY in ('rockslide','quartz'):
    for side in (-1,1):
        count=6 if KEY=='rockslide' else 5
        for j in range(count):
            # Keep the crown center open and all roots buried in the source body.
            d=Vector((side*(.74 if j%2==0 else .63),-.10+j*.165,.50 if j%2==0 else .67)).normalized()
            hit,point,normal,_=parts['Body'].ray_cast(d*4,-d);assert hit
            if point.dot(d)<.7:
                point=d/math.sqrt(d.x*d.x+(d.y/1.08)**2+(d.z/.96)**2);normal=d
            if KEY=='rockslide':
                color=[[117,127,138],[151,157,163],[95,106,119]][j%3]
                material=flat('Slate_'+str(side)+'_'+str(j),color,rough=.86)
                # Broad flattened irregular slabs, with lighter fractured side walls.
                u=normal.cross(Vector((0,1,0))).normalized();v=normal.cross(u).normalized()
                root=point-normal*.045;verts=[];sides=5
                for level in (0,1):
                    for k in range(sides):
                        a=k*math.tau/sides+.24*j;r=(.21+.018*((k+j)%3))*(1 if level==0 else .9)
                        verts.append(root+u*(math.cos(a)*r)+v*(math.sin(a)*r*.80)+normal*(level*.092))
                faces=[tuple(reversed(range(sides))),tuple(range(sides,sides*2))]
                faces.extend((k,(k+1)%sides,(k+1)%sides+sides,k+sides) for k in range(sides))
                ob=mesh(f'SlatePlate_{side}_{j}',verts,faces,material)
                ob.data.materials.append(flat('Slate fractured edge '+str(j),[166,163,150],rough=.91))
                for poly in ob.data.polygons:
                    if poly.index>1:poly.material_index=1
            else:
                color=[[239,197,229],[209,159,207],[249,221,239]][j%3]
                material=flat('Quartz_'+str(side)+'_'+str(j),color,rough=.17,metal=.1)
                direction=normal*.14+Vector((side*.018,.065,.24+(j%3)*.07))
                ob=crystal(f'QuartzCluster_{side}_{j}',point-normal*.065,direction,.102 if j%2 else .125,material,6)
                ob.data.materials.append(flat('Quartz cleaved face '+str(j),[170,126,181],rough=.24))
                for face in ob.data.polygons:
                    if face.index%6==1:face.material_index=1
            ob['rootEmbedded']=True

if TIER=='epic':
    if KEY=='ghost':
        # Thin tapered wisps, translucent instead of solid glowing noodles.
        for j in range(9):
            a=.16+j*(math.pi-.32)/8;r=1.16+.15*(j%2)
            z=-.63+.36*(j%3);base=Vector((r*math.cos(a),r*math.sin(a),z))
            points=[base+Vector((.09*math.sin(t*math.tau+j),.03*math.sin(t*math.pi),t*.48)) for t in np.linspace(0,1,14)]
            m=flat('Mist wisp '+str(j),[132,242,220],.8,rough=.8)
            m.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.36;m.surface_render_method='DITHERED'
            ob=tube('AuraWisp_'+str(j),points,[.001+.023*math.sin(t*math.pi)**1.3 for t in np.linspace(0,1,14)],m,auracol,sides=6)
            loop_bob(ob,.13,j*.61)
    else:
        for j in range(18):
            a=.10+j*(math.pi-.2)/17;r=1.15+.14*(j%3);pos=(r*math.cos(a),r*math.sin(a),-.75+(j%7)*.26)
            bpy.ops.mesh.primitive_cube_add(size=.027 if j%3 else .042,location=pos)
            ob=bpy.context.object;ob.name='AuraDataPixel_'+str(j);move(ob,auracol)
            assign(ob,flat(ob.name,P[2] if j%5==0 else P[1],1.1));aura.append(ob);loop_bob(ob,.08,j*.61)
