"""Update existing procedural coats without changing geometry, UVs or palettes.

Blender -b --python blender/pig/make/refresh_stripe_transitions.py -- glacier ...
Rebake with bake_skin.py afterwards. The legendary Rainbow Tiger uses a
separate hand-shaped atlas and does not use either of these stripe fields.
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bpy
import paths
from stripe_transition import soften_stripe_transition

keys = sys.argv[sys.argv.index('--') + 1:]
bpy.context.preferences.filepaths.save_version = 0
for key in keys:
    source = Path(paths.skin_blend(key))
    for scene_path in (source, source.with_name(key + '_closed.blend')):
        if not scene_path.exists():
            continue
        bpy.ops.wm.open_mainfile(filepath=str(scene_path))
        # Only materials actually assigned to the skin, never orphaned copies.
        materials = {m for name in ('Body', 'Snout', 'Ears', 'Legs', 'Tail')
                     for m in bpy.data.objects[name].data.materials if m}
        changed = sum(soften_stripe_transition(m) for m in materials)
        assert changed or any(m.get('stripe_transition_version') for m in materials), scene_path
        if changed:
            bpy.ops.wm.save_as_mainfile(filepath=str(scene_path))
        print('STRIPE_TRANSITION', key, scene_path.name, changed, flush=True)
