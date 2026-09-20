"""Normalize review output paths and resized FX handoffs; no geometry changes.

Run in Blender after a batch assembled while the resize brief was being updated.
"""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy
from house_paths import house_slug
from walkin_catalogue import SPECS,AUTHOR_SCALE,folder
BASE=Path(__file__).resolve().parents[1]
for slug,(rev,_,_) in SPECS.items():
    out=BASE/folder(slug,rev+1);source=BASE/folder(slug,rev)
    geo=json.loads((out/'geometry-report.json').read_text());scale=geo['walkIn']['bakedExteriorScale']
    fx=source/'animation-handoff.json'
    if fx.exists():
        def resized(value,key=''):
            if isinstance(value,dict):return {k:resized(v,k) for k,v in value.items()}
            if isinstance(value,list):
                if key in ('centerBlender','hingeBlender'):return [v*scale for v in value]
                return [resized(v,key) for v in value]
            if isinstance(value,(int,float)) and (key.endswith('Studs') or key in ('radius','height','tailEnvelope')):return value*scale
            return value
        (out/'animation-handoff.json').write_text(json.dumps(resized(json.loads(fx.read_text())),indent=2))
    path=out/f'{house_slug(slug)}.blend';bpy.ops.wm.open_mainfile(filepath=str(path))
    expected=str(out/'exterior.png')
    if bpy.context.scene.render.filepath!=expected:
        bpy.context.scene.render.filepath=expected
        bpy.ops.wm.save_as_mainfile(filepath=str(path))
print('Finalized all 18 review paths and final-size FX metadata; mesh geometry unchanged.')
