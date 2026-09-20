"""Render both shoulder joins and audit necklace spacing from the saved mesh."""
from pathlib import Path
import bpy, json
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
out = root / 'assets/shop-ui/icon-system-v1'
bpy.ops.wm.open_mainfile(filepath=str(out / 'sources/tiptoe.blend'))
scene = bpy.context.scene
links = sorted((o for o in scene.objects if o.name.startswith('ChainLink')), key=lambda o:o.name)
assert len(links) == 32
centers = [sum((o.matrix_world @ v.co for v in o.data.vertices), Vector()) / len(o.data.vertices) for o in links]
distances = [(centers[(i+1)%32]-centers[i]).length for i in range(32)]
# The previous discontinuity made either shoulder step roughly twice as large
# as the rest. Every adjacent pair must fit within the links' major radius.
reference=json.loads((root/'blender/shop/resident-reference.json').read_text())['parts']
unit=next(p for p in reference if p['name']=='Head')['size'][0]/4.7
assert max(distances) < .42*unit*.60, distances
proof=out/'review';proof.mkdir(exist_ok=True)
(proof/'necklace-spacing.json').write_text(json.dumps({'links':32,'adjacentDistances':distances,'maxDistance':max(distances),'passed':True},indent=2))
scene.render.resolution_x=scene.render.resolution_y=640
scene.cycles.samples=40
for name,index,offset in [('left',24,(-3,-6,4)),('right',8,(3,-6,4))]:
    target=centers[index]
    scene.camera.location=target+Vector(offset)
    scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera.data.ortho_scale=.62
    scene.render.filepath=str(proof/f'necklace-{name}.png')
    bpy.ops.render.render(write_still=True)
print('NECKLACE_SPACING_PASS',max(distances))
