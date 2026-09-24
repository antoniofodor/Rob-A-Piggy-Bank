"""Spatial texture fields; executed within build_arcade.py's authoring context."""
def paint(name,mode):
    p=Paint(name,P[0]);o=p.op;x,y,z=p.x,p.y,p.z
    def mul(a,b):return o('MULTIPLY',a,b)
    def add(a,b):return o('ADD',a,b)
    def sub(a,b):return o('SUBTRACT',a,b)
    def absolute(a):return o('ABSOLUTE',a)
    def less(a,b):return o('LESS_THAN',a,b)
    def greater(a,b):return o('GREATER_THAN',a,b)
    def both(a,b):return mul(a,b)
    def quant(a,n=22):return o('DIVIDE',add(o('FLOOR',mul(a,n)),.5),n)
    def hashv(a,b):return o('FRACT',mul(o('SINE',add(mul(a,12.9898),mul(b,78.233))),43758.5453))
    def box(a,b,cx,cy,rx,ry):return both(less(absolute(sub(a,cx)),rx),less(absolute(sub(b,cy)),ry))
    if KEY=='playerone':
        # Fixed pixel clusters in object space, not a low-resolution screen filter.
        qx,qy,qz=(quant(a) for a in (x,y,z))
        shade=add(add(mul(qx,-.22),mul(qy,-.30)),add(mul(qz,.43),.48))
        checker=o('MODULO',add(o('FLOOR',mul(y,22)),o('FLOOR',mul(z,22))),2)
        shade=add(shade,mul(sub(checker,.5),.045))
        reds=[[88,24,46],[134,29,47],[178,32,48],[218,44,56],[246,74,77],[255,125,115]]
        creams=[[129,97,73],[171,139,98],[206,179,130],[235,216,169],[255,237,195],[255,249,221]]
        cream=mode in ('snout','legs','ear','tail')
        if cream and mode!='ear':
            # Snout/limb local coordinates are not centered like the body.
            shade=add(1.10 if mode=='legs' else .68,mul(qz,.40 if mode=='legs' else .30))
            shade=add(shade,mul(qy,-.12))
        p.color=p.ramp(shade,creams if cream else reds,'CONSTANT');p.rough=1
        p.bs.inputs['Specular IOR Level'].default_value=0
        if mode=='body' and name.startswith('Body'):
            # Seven-row 1P bitmap, mirrored onto the two side surfaces.
            side_y=mul(y,o('SIGN',x))
            u=o('FLOOR',o('DIVIDE',add(side_y,.30),.065));v=o('FLOOR',o('DIVIDE',sub(.35,z),.065))
            bitmap=['01001110','11001001','01001001','01001110','01001000','01001000','11101000']
            glyph=0
            for row,line in enumerate(bitmap):
                for col,c in enumerate(line):
                    if c=='1':glyph=o('MAXIMUM',glyph,both(less(absolute(sub(u,col)),.1),less(absolute(sub(v,row)),.1)))
            glyph=both(glyph,greater(absolute(x),.78));p.color=p.mix(p.color,P[1],glyph)
    elif KEY=='retrocarpet':
        # Spherical wrap avoids the stretched markings of planar side projection.
        angle=o('ARCTAN2',y,x);radius=o('SQRT',add(mul(x,x),mul(y,y)))
        latitude=o('ARCTAN2',z,radius)
        u=mul(angle,2.22);v=mul(latitude,3.2)
        iu=o('FLOOR',u);iv=o('FLOOR',v);a=sub(o('FRACT',u),.5);b=sub(o('FRACT',v),.5)
        seed=hashv(iu,iv);kind=o('FLOOR',mul(seed,4))
        a=sub(a,mul(sub(hashv(add(iu,7),iv),.5),.16))
        b=sub(b,mul(sub(hashv(iu,add(iv,5)),.5),.16))
        flip=greater(hashv(add(iu,11),iv),.5)
        a=mul(a,sub(1,mul(flip,2)))
        for k in range(4):
            select=less(absolute(sub(kind,k)),.1)
            if k==0:
                wave=mul(sub(mul(absolute(sub(o('FRACT',mul(add(a,.32),3.2)),.5)),2),.5),.55)
                mark=both(less(absolute(sub(b,wave)),.115),less(absolute(a),.32));rgb=P[1]
            elif k==1:
                wave=mul(o('SINE',mul(a,15)),.17)
                mark=both(less(absolute(sub(b,wave)),.105),less(absolute(a),.33));rgb=P[2]
            elif k==2:
                # Equilateral triangle contour, signed distance to three sides.
                d=o('MAXIMUM',mul(b,-1),add(mul(absolute(a),.866),mul(b,.5)))
                mark=both(less(d,.21),greater(d,.12));rgb=P[3]
            else:
                mark=less(add(mul(a,a),mul(b,b)),.050);rgb=P[4]
            p.color=p.mix(p.color,rgb,both(mark,select))
        if mode=='snout':p.color=p.rgb([103,67,149])
        if mode in ('legs','ear'):p.color=p.rgb(P[1])
        if mode=='tail':p.color=p.rgb([70,43,112])
        if name.startswith('Ears') and mode=='body':p.color=p.rgb(P[0])
        p.rough=.82
    elif KEY=='respawn':
        u=mul(y,9);v=mul(z,9);iu=o('FLOOR',u);iv=o('FLOOR',v)
        cell=hashv(iu,iv)
        level=add(add(z,mul(y,-.20)),mul(cell,.55))
        pattern=less(level,.40)
        pattern=o('MAXIMUM',pattern,both(greater(cell,.93),less(z,.52)))
        bright=both(pattern,greater(cell,.47))
        ink=p.ramp(cell,[P[0],P[2],P[1],P[3]],'CONSTANT')
        p.color=p.mix(P[0],ink,pattern)
        p.glow=mul(bright,.70)
        if mode=='body' and name.startswith('Body'):
            qy=quant(y,16);qz=quant(z,16)
            stem=box(qy,qz,.05,.30,.055,.17)
            arrow=both(less(absolute(sub(qy,.05)),sub(.58,qz)),both(greater(qz,.37),less(qz,.58)))
            arrow=both(o('MAXIMUM',stem,arrow),greater(absolute(x),.74))
            p.color=p.mix(p.color,P[1],arrow);p.glow=o('MAXIMUM',p.glow,mul(arrow,1.15))
        if mode=='snout':p.color=p.rgb([66,36,119]);p.glow=0
        if mode=='ear':p.color=p.rgb([60,30,109]);p.glow=0
        if mode=='tail':p.color=p.rgb(P[2]);p.glow=0
        p.rough=.65
    elif KEY=='jackpot':
        p.color=p.rgb(P[0]);p.rough=.42
        if mode=='body':
            u=mul(y,2.2);v=mul(z,2.2)
            a=sub(o('FRACT',u),.5);b=sub(o('FRACT',v),.5)
            seed=hashv(o('FLOOR',u),o('FLOOR',v))
            diamond=less(add(absolute(a),absolute(b)),.22)
            angle=o('ARCTAN2',b,a);r=o('SQRT',add(mul(a,a),mul(b,b)))
            star=less(r,add(.15,mul(o('COSINE',mul(angle,5)),.06)))
            marks=o('MAXIMUM',both(star,less(seed,.36)),both(diamond,greater(seed,.69)))
            p.color=p.mix(p.color,P[2],marks)
        if mode in ('snout','ear'):p.color=p.rgb(P[1])
        if mode in ('legs','tail'):p.color=p.rgb(P[2]);p.metal=.55
    elif KEY=='pixel':
        q=p.vec(quant(o('ARCTAN2',y,x),12),quant(z,9),0)
        noise=mul(sub(p.noise(3.2,0,q),.27),2.3)
        p.color=p.ramp(noise,[P[0],P[0],P[1],P[2],P[3],P[3]],'CONSTANT')
        if mode in ('snout','ear','tail') or name.startswith('Ears'):p.color=p.rgb(P[2])
        if mode=='legs':p.color=p.rgb(P[3])
        p.rough=.8
    elif KEY=='circuitboard':
        # Repeating printed right-angle traces and solder pads in a wrapping field.
        angle=o('ARCTAN2',y,x);u=mul(angle,1.3);v=mul(z,2.0)
        a=sub(o('FRACT',u),.5);b=sub(o('FRACT',v),.5)
        seed=hashv(o('FLOOR',u),o('FLOOR',v))
        a=mul(a,sub(1,mul(greater(seed,.5),2)))
        trace=both(less(absolute(add(a,.22)),.029),less(b,.20))
        trace=o('MAXIMUM',trace,both(less(absolute(sub(b,.20)),.029),greater(a,-.22)))
        trace=o('MAXIMUM',trace,both(less(absolute(sub(a,.18)),.022),greater(b,.20)))
        trace=o('MAXIMUM',trace,both(less(absolute(add(b,.18)),.022),greater(a,-.05)))
        pad=p.ellipse((a,b),(-.22,-.27),(.080,.080))
        pad=o('MAXIMUM',pad,p.ellipse((a,b),(.18,.34),(.065,.065)))
        chip=both(box(a,b,.20,-.15,.12,.11),greater(seed,.58))
        p.color=p.mix(P[0],P[2],mul(seed,.32));p.color=p.mix(p.color,P[1],o('MAXIMUM',trace,pad));p.color=p.mix(p.color,P[3],chip)
        if mode=='snout':p.color=p.rgb([24,60,46])
        if mode in ('ear','legs'):p.color=p.rgb(P[1])
        if mode=='tail' or (name.startswith('Ears') and mode=='body'):p.color=p.rgb(P[0])
        p.rough=.62
    elif KEY=='powerup':
        qy=quant(y,14);qz=quant(z,14)
        bands=both(less(o('FRACT',mul(add(qy,mul(qz,.6)),3)),.30),less(z,-.25))
        p.color=p.mix(P[0],P[2],bands)
        stem=box(qy,qz,0,.10,.095,.27)
        head=both(less(absolute(qy),sub(.68,qz)),both(greater(qz,.28),less(qz,.68)))
        arrow=both(o('MAXIMUM',stem,head),greater(absolute(x),.67))
        p.color=p.mix(p.color,P[1],arrow);p.glow=mul(arrow,1.05)
        bars=both(less(absolute(sub(z,-.39)),.045),both(less(absolute(y),.36),less(o('FRACT',mul(y,9)),.65)))
        bars=both(bars,greater(absolute(x),.64));p.color=p.mix(p.color,P[3],bars);p.glow=o('MAXIMUM',p.glow,mul(bars,.5))
        if mode=='snout':p.color=p.rgb([65,122,83]);p.glow=0
        if mode=='legs':p.color=p.rgb(P[2]);p.glow=0
        if mode=='ear':p.color=p.rgb(P[1]);p.glow=0
        if mode=='tail' or (name.startswith('Ears') and mode=='body'):p.color=p.rgb(P[0]);p.glow=0
    elif KEY=='synthwave':
        long=o('ARCTAN2',y,x)
        gridu=less(absolute(sub(o('FRACT',mul(long,3.5)),.5)),.035)
        gridv=less(absolute(sub(o('FRACT',mul(z,6)),.5)),.030)
        grid=both(o('MAXIMUM',gridu,gridv),less(z,-.12))
        p.color=p.mix(P[0],P[1],grid);p.glow=mul(grid,.75)
        disc=p.ellipse((y,z),(.14,.13),(.43,.43));disc=both(disc,greater(absolute(x),.66))
        stripes=greater(o('FRACT',mul(z,14)),.22)
        sun=both(disc,stripes);suncolor=p.ramp(add(mul(z,1.5),.4),[P[2],P[3]])
        p.color=p.mix(p.color,suncolor,sun);p.glow=o('MAXIMUM',p.glow,mul(sun,.65))
        if mode=='snout':p.color=p.rgb([72,42,115]);p.glow=0
        if mode=='legs':p.color=p.mix(P[0],P[2],grid);p.glow=mul(grid,.65)
        if mode=='ear':p.color=p.rgb(P[2]);p.glow=0
        if mode=='tail' or (name.startswith('Ears') and mode=='body'):p.color=p.rgb(P[0]);p.glow=0
    elif KEY in ('finalboss','mechaplayer'):
        u=mul(add(y,mul(z,.35)),2.7);v=mul(z,2.7)
        a=o('FRACT',u);b=o('FRACT',v)
        edge=o('MINIMUM',o('MINIMUM',a,sub(1,a)),o('MINIMUM',b,sub(1,b)))
        panel=hashv(o('FLOOR',u),o('FLOOR',v))
        line=both(less(edge,.018),greater(panel,.43));line=both(line,greater(y,-.62))
        p.color=p.mix(P[0],P[2],mul(panel,.6));p.color=p.mix(p.color,[24,27,40],less(edge,.035))
        p.color=p.mix(p.color,P[1],line);p.glow=mul(line,.85)
        if KEY=='finalboss':
            face=both(less(y,-.64),greater(z,-.25))
            p.color=p.mix(p.color,[225,143,172],face);p.glow=mul(p.glow,sub(1,face))
        if KEY=='mechaplayer':
            warning=both(less(absolute(add(z,.34)),.055),less(o('FRACT',mul(add(y,z),12)),.5))
            p.color=p.mix(p.color,P[3],warning)
        if mode=='snout':p.color=p.rgb([218,121,151] if KEY=='finalboss' else [87,120,147]);p.glow=0
        if mode=='legs':p.color=p.rgb([214,128,157] if KEY=='finalboss' else P[2]);p.glow=0
        if mode=='ear':p.color=p.rgb([201,104,144] if KEY=='finalboss' else P[1]);p.glow=0
        if mode=='tail' or (name.startswith('Ears') and mode=='body'):p.color=p.rgb([222,146,176] if KEY=='finalboss' else P[0]);p.glow=0
    paints[name]=p
    return p.finish()
