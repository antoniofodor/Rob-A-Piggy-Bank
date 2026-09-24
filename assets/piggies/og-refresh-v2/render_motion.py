"""Render the saved surface animation, never CSS-simulated effects."""
from pathlib import Path
import argparse,sys,json,bpy
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
p=argparse.ArgumentParser();p.add_argument('--skin',required=True)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
spec=next(s for s in json.loads((HERE/'design-specs.json').read_text())['skins'] if s['key']==args.skin)
HOME=ROOT/'assets/piggies'/spec['tier']/args.skin/'revisions/og-v2'
bpy.ops.wm.open_mainfile(filepath=str(HOME/'package'/f'{args.skin}-og-v2.blend'))
scene=bpy.context.scene;scene.render.resolution_x=480;scene.render.resolution_y=480;scene.cycles.samples=6
out=HOME/'preview/frames';out.mkdir(exist_ok=True)
for i,f in enumerate(range(1,145,3)):
    scene.frame_set(f);scene.render.filepath=str(out/f'motion-{i:02d}.png');bpy.ops.render.render(write_still=True)
print('MOTION_COMPLETE',args.skin,flush=True)
