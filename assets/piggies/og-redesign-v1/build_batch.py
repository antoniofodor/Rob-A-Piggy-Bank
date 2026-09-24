"""Run independent Blender builds, two at a time, with per-skin logs."""
from pathlib import Path
import argparse, concurrent.futures, json, subprocess
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
parser=argparse.ArgumentParser();parser.add_argument('--keys',required=True);parser.add_argument('--workers',type=int,default=2)
args=parser.parse_args();keys=args.keys.split(',')
logs=HERE/'logs';logs.mkdir(exist_ok=True)
def build(key):
    with (logs/(key+'.log')).open('w',encoding='utf-8') as log:
        p=subprocess.run([r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe','--background','--python-exit-code','1','--python',str(HERE/'build_og.py'),'--','--skin',key],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    return key,p.returncode
failed=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
    futures=[pool.submit(build,key) for key in keys]
    for future in concurrent.futures.as_completed(futures):
        key,code=future.result();print(('DONE ' if code==0 else 'FAILED ')+key,flush=True)
        if code:failed.append(key)
print(json.dumps({'keys':keys,'failed':failed}),flush=True)
raise SystemExit(bool(failed))
