from pathlib import Path
import subprocess,concurrent.futures,argparse
from PIL import Image,ImageChops
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
p=argparse.ArgumentParser();p.add_argument('--keys',default='ghost,hologram,aurora,neonmint');args=p.parse_args()
def render(key):
    with (HERE/'logs'/f'{key}-motion.log').open('w') as log:
        r=subprocess.run([r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe','-b','-t','8','--python-exit-code','1','--python',str(HERE/'render_motion.py'),'--','--skin',key],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    if r.returncode:return key,False
    tier='epic' if key in ('ghost','hologram') else 'rare'
    preview=ROOT/'assets/piggies'/tier/key/'revisions/og-v2/preview'
    paths=sorted((preview/'frames').glob('motion-*.png'));assert len(paths)==48
    frames=[Image.open(p).convert('RGB') for p in paths]
    assert ImageChops.difference(frames[0],frames[12]).getbbox(),key+' frozen animation'
    frames[0].save(preview/f'{key}-og-v2-motion.webp',save_all=True,append_images=frames[1:],duration=125,loop=0,quality=89,method=5)
    print('MOTION_READY',key,flush=True);return key,True
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results=list(pool.map(render,args.keys.split(',')))
print(results,flush=True)
assert all(ok for _,ok in results)
