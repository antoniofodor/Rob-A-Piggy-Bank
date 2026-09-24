import bpy,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/piggies/legendary/rainbowtiger/revisions/tail-tip-v2'
source=OUT/'rainbowtiger-complete.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene;scene.frame_set(1)
for o in scene.objects:
 if o.type=='MESH' and 'bone' not in o:o.hide_render=True
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.cycles.samples=32
scene.render.filepath=str(OUT/'rainbowtiger-shop-card.png');bpy.ops.render.render(write_still=True)
(OUT/'shop-card.json').write_text(json.dumps({'source':source.relative_to(ROOT).as_posix(),'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'image':'rainbowtiger-shop-card.png'},indent=2))
