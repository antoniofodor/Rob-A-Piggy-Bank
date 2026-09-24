"""Authored coat fields, baked to the existing pig UVs by build.py."""
P=SPEC['palette'];paints={}

def paint(name,mode):
    p=Paint(name,P[0]);o=p.op;x,y,z=p.x,p.y,p.z
    def add(a,b):return o('ADD',a,b)
    def sub(a,b):return o('SUBTRACT',a,b)
    def mul(a,b):return o('MULTIPLY',a,b)
    def ab(a):return o('ABSOLUTE',a)
    def lt(a,b):return o('LESS_THAN',a,b)
    def gt(a,b):return o('GREATER_THAN',a,b)
    def clamp(a):return o('MINIMUM',1,o('MAXIMUM',0,a))
    theta=o('ARCTAN2',y,x)
    p.opacity=1
    n=p.noise(3.4,2)
    if KEY=='aurora':
        flow=add(mul(o('SINE',add(mul(y,2.5),mul(x,.9))),.26),mul(o('SINE',add(mul(y,5.2),.3)),.065))
        t=sub(z,flow)
        field=clamp(o('DIVIDE',add(t,.22),.93))
        ribbon=mul(gt(t,-.28),lt(t,.74))
        feather=mul(clamp(mul(add(t,.28),11)),clamp(mul(sub(.74,t),7)))
        curtain=p.ramp(field,[[23,50,87],[49,206,152],[76,229,195],[75,153,219],[154,101,219],[49,44,99]])
        folds=add(.74,mul(o('SINE',add(mul(y,71),mul(n,4))),.12))
        ribbon=mul(feather,folds)
        p.color=p.mix(P[0],curtain,ribbon)
        stars=mul(lt(p.vor(19,'F1').outputs['Distance'],.092),gt(t,.6))
        p.color=p.mix(p.color,[188,226,240],stars);p.glow=mul(ribbon,.3);p.rough=.4;p.metal=.08
        if mode=='snout':p.color=p.rgb([57,65,112]);p.glow=0
        if mode=='ear':p.color=p.rgb([142,119,194]);p.glow=0
        if mode=='legs':p.color=p.mix([40,62,98],[80,207,185],lt(z,-.87));p.glow=.06
    elif KEY=='banker':
        # Longitude stripes travel from the front seam to the tail.
        pin=p.stripe(add(mul(y,28),mul(x,.6)),.115)
        p.color=p.mix(P[0],[126,148,160],pin)
        face=mul(lt(y,-.49),gt(z,add(-.24,mul(ab(x),.10))))
        p.color=p.mix(p.color,[237,169,183],face)
        front=lt(y,-.64)
        bib=mul(front,mul(lt(z,-.22),lt(ab(x),add(.57,mul(z,.19)))))
        p.color=p.mix(p.color,[232,229,214],bib)
        lapel=mul(front,mul(lt(z,-.24),mul(gt(ab(x),add(.49,mul(z,.20))),lt(ab(x),add(.55,mul(z,.20))))))
        p.color=p.mix(p.color,[133,151,171],lapel)
        tie=mul(bib,mul(gt(z,-.90),lt(ab(x),sub(.115,mul(ab(add(z,.54)),.1)))))
        p.color=p.mix(p.color,[129,35,62],tie)
        # Gold watch and a double chain, placed on each side of the waistcoat.
        d=o('SQRT',add(mul(sub(y,.32),sub(y,.32)),mul(add(z,.21),add(z,.21))))
        watch=mul(gt(ab(x),.65),lt(d,.125))
        ring=mul(watch,gt(d,.096));dial=mul(watch,lt(d,.092))
        p.color=p.mix(p.color,[225,213,173],dial)
        chainZ=add(-.24,mul(o('POWER',sub(y,.05),2),1.1))
        chain=mul(gt(ab(x),.70),mul(gt(y,-.35),mul(lt(y,.32),lt(ab(sub(z,chainZ)),.012))))
        chain=o('MAXIMUM',chain,mul(gt(ab(x),.70),mul(gt(y,-.35),mul(lt(y,.32),lt(ab(sub(z,sub(chainZ,.037))),.006)))))
        gold=o('MAXIMUM',ring,chain)
        for cy,cz in [(-.58,-.39),(-.50,-.62)]:
            button=mul(gt(ab(x),.52),p.ellipse((y,z),(cy,cz),(.038,.038)));gold=o('MAXIMUM',gold,button)
        p.color=p.mix(p.color,[212,172,84],gold);p.metal=mul(gold,.68);p.rough=sub(.63,mul(gold,.33))
        if mode in ('snout','tail','ear','ear_outer'):
            p.color=p.rgb([234,164,179] if mode!='ear' else [180,103,137]);p.metal=0;p.rough=.5
        if mode=='legs':
            cuff=mul(gt(z,-.85),lt(z,-.79));p.color=p.mix([25,29,42],[232,226,208],cuff);p.rough=.27
    elif KEY=='rockslide':
        warp=p.vec(x,add(y,mul(n,.11)),add(z,mul(n,.15)))
        edges=lt(p.vor(2.65,'DISTANCE_TO_EDGE',warp).outputs['Distance'],.021)
        cell=p.vor(2.65,'F1',warp).outputs['Color']
        strata=add(mul(z,27),add(mul(y,4),mul(n,3)))
        bands=mul(add(o('SINE',strata),1),.5)
        color=p.mix([81,90,104],[146,153,156],cell)
        p.color=p.mix(color,[191,184,165],mul(bands,.22));p.color=p.mix(p.color,[46,52,62],edges)
        grain=p.noise(95,1);p.color=p.mix(p.color,[187,187,177],mul(lt(grain,.32),.28));p.rough=.88
        if mode=='ear':p.color=p.mix(p.color,[77,78,88],.3)
    elif KEY=='quartz':
        u=add(mul(y,3.8),mul(x,.75));v=add(mul(z,3.8),mul(y,.55))
        row=o('FLOOR',v);u=add(u,mul(row,.5))
        diagonal=gt(add(o('FRACT',u),o('FRACT',v)),1)
        index=o('FRACT',mul(add(add(o('FLOOR',u),mul(row,3)),diagonal),.173))
        p.color=p.ramp(index,[[213,157,195],[246,211,229],[234,182,215],[251,229,240]],'CONSTANT')
        cloud=clamp(mul(sub(p.noise(3),.49),3));p.color=p.mix(p.color,[251,232,242],cloud)
        veins=lt(p.vor(2.9,'DISTANCE_TO_EDGE',p.vec(x,add(y,mul(n,.15)),z)).outputs['Distance'],.009)
        p.color=p.mix(p.color,[255,243,248],mul(veins,.65));p.metal=.08;p.rough=.21
        if mode=='snout':p.color=p.mix(p.color,[232,178,210],.65)
        if mode=='ear':p.color=p.mix(p.color,[193,143,188],.55)
    elif KEY=='neonmint':
        phase=add(mul(z,8.6),add(mul(o('SINE',mul(y,2.5)),1.6),mul(y,1.1)))
        wave=o('SINE',phase);mint=gt(wave,-.25)
        edge=mul(gt(wave,-.48),lt(wave,-.29))
        p.color=p.mix(P[0],P[1],mint);p.color=p.mix(p.color,P[2],edge)
        p.glow=add(mul(mint,.14),mul(edge,.65));p.rough=.30;p.metal=.12
        if mode=='snout':p.color=p.rgb([25,75,74]);p.glow=0;p.rough=.34
        if mode=='ear':p.color=p.rgb([171,253,222]);p.glow=.13
        if mode=='legs':p.color=p.mix(P[0],P[1],lt(z,-.81));p.glow=mul(lt(z,-.81),.18)
    elif KEY=='ghost':
        w=p.noise(3.1,2,p.vec(mul(x,1.5),mul(y,1.5),mul(z,.42)))
        mist=clamp(mul(sub(w,.30),2.4))
        p.color=p.mix([122,214,206],[224,251,246],mist)
        fade=clamp(o('DIVIDE',add(z,1.0),1.05))
        p.opacity=mul(add(.27,mul(mist,.15)),fade)
        p.glow=add(.28,mul(mist,.15));p.rough=.68
        if mode=='snout':p.opacity=.49;p.color=p.rgb([188,241,234]);p.glow=.25
        if mode=='ear':p.color=p.rgb([102,195,192]);p.opacity=.43
    elif KEY=='hologram':
        scan=p.stripe(mul(z,67),.095)
        meridian=o('ARCTAN2',x,y)
        grid=o('MAXIMUM',p.stripe(mul(meridian,9),.055),p.stripe(mul(z,10),.05))
        bars=mul(p.stripe(mul(z,23),.12),gt(p.noise(6),.63))
        marks=o('MAXIMUM',grid,mul(scan,.42))
        p.color=p.mix([24,112,144],P[1],marks);p.color=p.mix(p.color,P[2],bars)
        p.opacity=add(.16,o('MAXIMUM',mul(marks,.56),mul(bars,.65)))
        p.glow=add(.12,mul(o('MAXIMUM',marks,bars),.85));p.rough=.62
        if mode=='snout':p.opacity=add(p.opacity,.15)
        if mode=='ear':p.opacity=add(p.opacity,.05)
    paints[name]=p
    return p.finish()

for name,mode in [('Body','body'),('Snout','snout'),('Legs','legs'),('Tail','tail')]:assign(parts[name],paint(name+'_coat',mode))
ears=parts['Ears']
for i in range(len(ears.data.materials)):ears.data.materials[i]=paint('Ears_'+str(i),'ear_outer' if i==0 else 'ear')
eyes=flat('Eyes',[14,40,53] if KEY=='ghost' else [112,235,255] if KEY=='hologram' else [20,24,34],.35 if KEY=='hologram' else 0,rough=.4)
assign(parts['EyePreview'],eyes)

def decorate_material(mat,group):
    """Shader effects are retained in Blender, with a separate runtime recipe."""
    nt=mat.node_tree;bs=nt.nodes['Principled BSDF'];n=nt.nodes;l=nt.links
    def mathnode(op,a,b):
        v=n.new('ShaderNodeMath');v.operation=op
        for value,sock in [(a,v.inputs[0]),(b,v.inputs[1])]:
            if isinstance(value,(int,float)):sock.default_value=value
            else:l.new(value,sock)
        return v.outputs[0]
    def source(socket):return socket.links[0].from_socket if socket.is_linked else socket.default_value
    if KEY in ('aurora','neonmint','ghost','hologram'):
        pulse=n.new('ShaderNodeValue');pulse.name='Six second material shimmer'
        for f,value in [(1,.86),(37,1.17),(73,.86),(109,1.17),(145,.86)]:
            pulse.outputs[0].default_value=value;pulse.outputs[0].keyframe_insert(data_path='default_value',frame=f)
        glow=mathnode('MULTIPLY',source(bs.inputs['Emission Strength']),pulse.outputs[0])
        l.new(glow,bs.inputs['Emission Strength'])
    if KEY in ('ghost','hologram'):
        alpha=source(bs.inputs['Alpha']);lw=n.new('ShaderNodeFresnel');lw.inputs['IOR'].default_value=1.25
        edge=lw.outputs['Fac']
        # Fresnel weights the grazing silhouette rather than the broad face.
        alpha=mathnode('ADD',alpha,mathnode('MULTIPLY',edge,.38 if KEY=='ghost' else .24))
        glow=mathnode('ADD',source(bs.inputs['Emission Strength']),mathnode('MULTIPLY',edge,.5))
        if KEY=='hologram':
            tex=n.new('ShaderNodeTexCoord');xyz=n.new('ShaderNodeSeparateXYZ');l.new(tex.outputs['Object'],xyz.inputs[0])
            phase=n.new('ShaderNodeValue');phase.name='Scan position'
            for f,z in [(1,-1.45),(145,1.55)]:phase.outputs[0].default_value=z;phase.outputs[0].keyframe_insert(data_path='default_value',frame=f)
            dist=mathnode('ABSOLUTE',mathnode('SUBTRACT',xyz.outputs['Z'],phase.outputs[0]),0)
            band=mathnode('MULTIPLY',mathnode('LESS_THAN',dist,.046),.75)
            alpha=mathnode('ADD',alpha,band);glow=mathnode('ADD',glow,mathnode('MULTIPLY',band,1.6))
        geom=n.new('ShaderNodeNewGeometry');front=mathnode('SUBTRACT',1,geom.outputs['Backfacing'])
        # Back faces are suppressed to prevent opaque-looking stacks of intersecting pig pieces.
        # The designer approved the layered version: retain internal outlines.
        l.new(mathnode('MULTIPLY',alpha,front),bs.inputs['Alpha']);l.new(glow,bs.inputs['Emission Strength'])
        bs.inputs['Specular IOR Level'].default_value=.1
        mat.diffuse_color=(*lin(P[0]),.45);mat.surface_render_method='DITHERED'
        mat.use_transparency_overlap=False
