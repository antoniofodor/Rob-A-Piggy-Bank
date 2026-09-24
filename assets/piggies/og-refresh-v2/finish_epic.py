from pathlib import Path
import argparse,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
p=argparse.ArgumentParser();p.add_argument('--skin',choices=['ghost','hologram'],required=True);args=p.parse_args()
with (HERE/'logs'/f'{args.skin}-projection.log').open('w') as log:
    subprocess.run([r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe','-b','-t','8','--python-exit-code','1','--python',str(HERE/'clean_projection.py'),'--','--skin',args.skin],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
print('CLEAN_SURFACE_READY',args.skin,flush=True)
subprocess.run([sys.executable,str(HERE/'motion_batch.py'),'--keys',args.skin],cwd=ROOT,check=True)
