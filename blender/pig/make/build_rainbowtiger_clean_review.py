"""Remove rejected brows and all fur for the next Rainbow Tiger concept review.

Preserves legendary-v1 as the previous review, including its liked tail design.
This clean scene is a review base, not a newly approved production package.
"""
from pathlib import Path
import bpy,json,hashlib

ROOT=Path(__file__).resolve().parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
SOURCE=Path(paths.skin_study('rainbowtiger','legendary-v1'))/'rainbowtiger-complete.blend'
OUT=Path(paths.skin_study('rainbowtiger','clean-review-v2'))
OUT.mkdir(parents=True,exist_ok=True)
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
removed=[]
prefixes=('Ruff_','Cheek_','EarFur','Brow','FootCuff_','FootTufts','TailPlume','TailFur','TailTuft_')
for ob in list(bpy.data.objects):
    if ob.type=='MESH' and ob.name.startswith(prefixes):
        removed.append(ob.name);bpy.data.objects.remove(ob,do_unlink=True)
assert removed and not any(o.type=='MESH' and o.name.startswith(prefixes) for o in bpy.data.objects)
parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and 'bone' in o]
assert all(name in bpy.data.objects for name in ('Body','Snout','Ears','Eyes','Legs','Tail'))
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for ob in parts+[bpy.data.objects['RainbowTiger_Rig']]:ob.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['RainbowTiger_Rig']
bpy.ops.export_scene.fbx(filepath=str(OUT/'rainbowtiger-clean-review.fbx'),use_selection=True,object_types={'MESH','ARMATURE'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False,path_mode='COPY',use_triangles=True)
scene=bpy.context.scene;scene.render.resolution_x=640;scene.render.resolution_y=640;scene.cycles.samples=8
scene.render.filepath=str(OUT/'clean-model-hero.png')
bpy.ops.render.render(write_still=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rainbowtiger-clean-review.blend'))
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
(OUT/'cleanup-report.json').write_text(json.dumps({'status':'Clean review base; concept approval and Studio integration pending','removedMeshes':removed,'remainingMeshes':[o.name for o in parts],'previousModelPreserved':str(SOURCE),'previousModelSHA256':source_hash},indent=2))
(OUT/'README.md').write_text('# Rainbow Tiger — clean review base\n\nAll added fur and protruding eyebrow meshes were removed from this working\ncopy, including the tail plume, following the request to delete all hair.\nBlack coat, wraparound and forehead stripes, RGB eyes, original bare pig tail,\nsnout, feet and bank openings remain. Previous tail art is preserved in\n`../legendary-v1/`. The previous ruff bones remain unused in this review rig.\n\nThe generated concept image is separate from this actual Blender cleanup.\nConcept review and Studio integration are pending.\n',encoding='utf-8')
print('CLEAN_REVIEW_READY',json.dumps({'removed':removed,'remainingMeshCount':len(parts)}))
