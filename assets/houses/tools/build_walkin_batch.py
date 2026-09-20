"""Build independent walk-in model packages and exports with bounded workers.

python assets/houses/tools/build_walkin_batch.py [stable IDs...]
"""
import concurrent.futures,json,os,subprocess,sys
from pathlib import Path
from walkin_catalogue import SPECS,folder
ROOT=Path(__file__).resolve().parents[3]
BLENDER=os.environ.get('BLENDER_EXE',r'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe')
LOG=ROOT/'assets/houses/walk-in-review';LOG.mkdir(exist_ok=True)
def run(slug):
    stages=[('build_walkin.py',[slug]),('export_house_roblox.py',[slug,str(SPECS[slug][0]+1)])]
    for script,args in stages:
        log=LOG/f'{slug}-{script[:-3]}.log'
        with log.open('w',encoding='utf-8') as handle:
            result=subprocess.run([BLENDER,'-b','-t','3','--python-exit-code','1','--python',str(Path(__file__).parent/script),'--',*args],cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT)
        if result.returncode:
            return {'id':slug,'success':False,'stage':script,'log':str(log.relative_to(ROOT))}
    return {'id':slug,'success':True,'folder':folder(slug,SPECS[slug][0]+1)}
if __name__=='__main__':
    ids=sys.argv[1:] or list(SPECS)
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for result in pool.map(run,ids):
            results.append(result);print(json.dumps(result),flush=True)
            (LOG/'batch-results.json').write_text(json.dumps(results,indent=2))
    raise SystemExit(0 if all(r['success'] for r in results) else 1)
