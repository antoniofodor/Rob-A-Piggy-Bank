"""Reproducible color and emission atlases for Crystal Crown feather meshes.

Each of 16 tiles has padded UVs; feather veins follow their own longitudinal UVs.
The Face tile is projected in body X/Z. No source raster is edited or sampled.
"""
import math, struct, zlib
import numpy as np

SIZE=2048
TILE=512
def uv(index,u=.5,v=.02):
    return ((index%4+.006+.988*u)/4, (3-index//4+.006+.988*v)/4)

def line(mask,a,b,radius=2):
    ax,ay=a[0]*(TILE-1),(1-a[1])*(TILE-1)
    bx,by=b[0]*(TILE-1),(1-b[1])*(TILE-1)
    x0=max(0,int(min(ax,bx)-radius-2));x1=min(TILE,int(max(ax,bx)+radius+3))
    y0=max(0,int(min(ay,by)-radius-2));y1=min(TILE,int(max(ay,by)+radius+3))
    if x1<=x0 or y1<=y0:return
    yy,xx=np.mgrid[y0:y1,x0:x1]
    dx,dy=bx-ax,by-ay;t=np.clip(((xx-ax)*dx+(yy-ay)*dy)/max(dx*dx+dy*dy,1e-8),0,1)
    strength=np.clip(radius+.65-np.sqrt((xx-ax-t*dx)**2+(yy-ay-t*dy)**2),0,1)
    mask[y0:y1,x0:x1]=np.maximum(mask[y0:y1,x0:x1],strength)

def poly(mask,points,radius=2):
    for a,b in zip(points,points[1:]):line(mask,a,b,radius)

def curve(mask,points,radius=2):
    points=[np.array(p,dtype=float) for p in points]
    for i in range(len(points)-1):
        p0=points[max(0,i-1)];p1=points[i];p2=points[i+1];p3=points[min(len(points)-1,i+2)]
        last=p1
        for t in np.linspace(0,1,13)[1:]:
            pos=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
            line(mask,last,pos,radius*(1-.50*(i+t)/(len(points)-1)));last=pos

def png(path,data):
    def chunk(kind,value):return struct.pack('>I',len(value))+kind+value+struct.pack('>I',zlib.crc32(kind+value)&0xffffffff)
    h,w=data.shape[:2];raw=b''.join(b'\0'+row.tobytes() for row in data)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))

def build(folder,palette):
    assert len(palette)==16
    color=np.zeros((SIZE,SIZE,3),dtype=np.uint8);emission=np.zeros_like(color)
    yy,xx=np.mgrid[0:TILE,0:TILE];u=xx/(TILE-1);t=1-yy/(TILE-1)
    def smooth(x):x=np.clip(x,0,1);return x*x*(3-2*x)
    coverage={}
    for index,(name,rgb) in enumerate(palette.items()):
        base=np.zeros((TILE,TILE,3),dtype=float)+rgb;mask=np.zeros((TILE,TILE))
        veins=np.zeros((TILE,TILE));outline=np.zeros_like(veins)
        if name.startswith(('Feather','Glow')):
            glow=name.startswith('Glow')
            grad=smooth((t-.12)/.85)
            tip=smooth((t-(.60 if glow else .68))/.27)
            base=base*(1-grad[...,None]*.75)+np.array((115,203,232))*grad[...,None]*.75
            # A gentle central facet and blue edges preserve depth between pulses.
            facet=.91+.11*np.cos((u-.5)*math.pi*2)+.06*np.sin(t*10+u*4)
            base*=facet[...,None]
            base=base*(1-tip[...,None]*.80)+np.array((206,249,255))*tip[...,None]*.80
            trunk=[(.48,.13),(.51,.29),(.49,.44),(.53,.60),(.50,.76),(.51,.93)]
            poly(veins,trunk,1.6)
            for sign in (-1,1):
                for k,v in enumerate((.30,.44,.58,.70)):
                    root=(.50,v);mid=(.50+sign*(.13+.015*(k%2)),v+.07)
                    end=(.50+sign*(.30-.025*k),v+.15)
                    poly(veins,[root,mid,end],1.25)
                    line(veins,mid,(mid[0]+sign*.025,mid[1]+.09),.85)
            visibility=(.30+.65*smooth((t-.18)/.65))*veins
            base=base*(1-visibility[...,None])+np.array((211,252,255))*visibility[...,None]
            mask=np.maximum(tip*(1 if glow else .80),visibility*(.38 if glow else .20))
        elif name=='Face':
            # Coordinates below are in the pig's X/Z frame, mapped to this tile.
            def mapped(point):return ((point[0]+1)/2,(point[1]+1)/2)
            paths=[]
            for sign in (-1,1):
                def mirror(points):return [(sign*x,z) for x,z in points]
                paths.append(mirror([(.12,.52),(.23,.61),(.36,.66),(.48,.68),(.56,.73)]))
                for x,z in [(.23,.61),(.34,.65),(.45,.68)]:
                    paths.extend([mirror([(x,z),(x-.04,z+.09),(x-.035,z+.13)]),mirror([(x,z),(x+.10,z+.015),(x+.14,z+.04)])])
                paths.append(mirror([(.47,.18),(.53,.30),(.54,.43),(.59,.54),(.65,.59)]))
                for x,z in [(.52,.28),(.54,.40),(.58,.51)]:
                    paths.extend([mirror([(x,z),(x+.08,z+.03),(x+.10,z+.07)]),mirror([(x,z),(x-.035,z+.07)])])
            for points in paths:
                curve(outline,list(map(mapped,points)),1.8)
                curve(veins,list(map(mapped,points)),.55)
                if len(points)<=3:
                    # Tapered crystalline leaflets make the branches fern-like.
                    end=np.array(mapped(points[-1]));prev=np.array(mapped(points[-2]))
                    start=end*.28+prev*.72
                    for t in np.linspace(0,1,18):
                        pos=start*(1-t)+end*t
                        line(outline,pos,pos,2.2*math.sin(math.pi*t)+.25)
                    line(veins,start,end,.40)
            for i in range(6):
                angle=i*math.tau/6;center=(0,.59);end=(.062*math.sin(angle),.59+.062*math.cos(angle))
                line(outline,mapped(center),mapped(end),1.8);line(veins,mapped(center),mapped(end),.5)
            base=base*(1-outline[...,None]*.80)+np.array((95,183,218))*outline[...,None]*.80
            base=base*(1-veins[...,None]*.80)+np.array((210,254,255))*veins[...,None]*.80
            mask=veins*.13
        elif name=='Snout':
            # Narrow upper snout flourish, far above the nostril interiors.
            for sign in (-1,1):
                points=[(.5,.89),(.5+sign*.12,.875),(.5+sign*.24,.83)]
                curve(outline,points,1.8);curve(veins,points,.6)
                for k in (1,2):
                    a=(.5+sign*.08*k,.89-.013*k);b=(a[0]+sign*.045,a[1]+.026)
                    line(outline,a,b,1.7);line(veins,a,b,.7)
            base=base*(1-outline[...,None]*.45)+np.array((109,213,241))*outline[...,None]*.45
            base=base*(1-veins[...,None]*.9)+np.array((209,254,255))*veins[...,None]*.9
            mask=veins*.18
        y=(index//4)*TILE;x=(index%4)*TILE
        color[y:y+TILE,x:x+TILE]=np.clip(base,0,255).astype(np.uint8)
        emission[y:y+TILE,x:x+TILE]=np.repeat(np.uint8(np.clip(mask,0,1)*255)[...,None],3,axis=2)
        coverage[name]=float(np.mean(mask>.10))
    png(folder/'phoenix_color.png',color);png(folder/'phoenix_emissive.png',emission)
    return dict(size=[SIZE,SIZE],tiles=list(palette),maskCoverage=coverage)
