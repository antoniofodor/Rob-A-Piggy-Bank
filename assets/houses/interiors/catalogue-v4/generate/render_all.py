"""Render independent theme files in three bounded Blender processes."""
import concurrent.futures
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]
BLENDER='C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
rows=json.loads((ROOT/'manifest.json').read_text())
def run(row):
    theme=row['slug']
    with (ROOT/theme/'render.log').open('w') as log:
        result=subprocess.run([BLENDER,'-b','-t','3','--python-exit-code','1','--python',str(ROOT/'generate/render.py'),'--','--theme',theme,'--only','hall','--draft'],stdout=log,stderr=subprocess.STDOUT)
    if result.returncode: raise RuntimeError(theme+' render failed; see render.log')
    return theme
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    for done in concurrent.futures.as_completed([pool.submit(run,row) for row in rows]):
        print('Rendered '+done.result(),flush=True)
