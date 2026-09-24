"""Derive a self-contained Arcade pipeline from the verified OG authoring pipeline."""
from pathlib import Path
HERE=Path(__file__).resolve().parent
src=(HERE.parent/'og-redesign-v1/build_og.py').read_text()
start=src.index('def paint(name,mode):');end=src.index("assign(parts['Body']",start)
src=src[:start]+(HERE/'arcade_paint.py').read_text()+'\n\n'+src[end:]
start=src.index("if KEY in ('rockslide','quartz'):");end=src.index('assert signatures==',start)
geometry=(HERE/'arcade_geometry.py').read_text()
geometry=geometry.replace('# Separate small visual proxies', (HERE/'expansion_geometry.py').read_text()+'\n\n# Separate small visual proxies')
geometry=geometry.replace("P[1] if KEY=='respawn' else P[-1]", "P[1] if KEY in ('respawn','powerup','synthwave','finalboss','mechaplayer') else P[-1]")
src=src[:start]+geometry+'\n\n'+src[end:]
src=src.replace('og-redesign-v1','arcade-build-v1').replace('build_og.py','build_arcade.py').replace('og-v1','arcade-v1').replace('_og_v1','_arcade_v1').replace(' - OG v1',' - Arcade v1').replace('OG_COMPLETE','ARCADE_COMPLETE')
src=src.replace("eye_rgb=P[1] if KEY=='hologram' else P[2] if KEY=='prismatic' else P[-1]","eye_rgb=P[1]")
src=src.replace("KEY not in ('nightlight','sugarrush')","KEY in ('respawn','powerup','synthwave','finalboss','mechaplayer')")
src=src.replace("elif KEY in ('rockslide','charcoal'):p.inputs['Roughness'].default_value=.88", "elif KEY=='playerone':\n        p.inputs['Roughness'].default_value=1\n        p.inputs['Specular IOR Level'].default_value=0\n        tex.interpolation='Closest'")
src=src.replace("world.node_tree.nodes['Background'].inputs[1].default_value=.5","world.node_tree.nodes['Background'].inputs[1].default_value=.4")
src=src.replace("370,5);light('Fill',(4,-1,3),190,4);light('Rim',(1,4,5),390,3)","310,5);light('Fill',(4,-1,3),145,4);light('Rim',(1,4,5),260,3)")
src=src.replace("(185,187,189)","(53,47,66)")
src=src.replace("scene.cycles.samples=16", "scene.cycles.samples=24")
src=src.replace("size=1024", "size=1024")
src=src.replace("Use existing aura key; preview motes are not export meshes.","Aura keys are proposed new emitters; preview motes are not export meshes.")
src=src.replace("Preserve rarity.","Player One is Rare for its authored pixel coat; these are new assets, not installed Config rows.")
src=src.replace('Build the 15 OG redesigns','Build the approved Arcade collection')
marker="(HOME/'package/arcade-v1-asset-report.json').write_text"
src=src.replace(marker,"""if KEY=='jackpot':
    for index in range(3):
        path=HOME/'sheets'/f'jackpot_arcade_v1_reel_{index}.png'
        report['textures'].append({'role':f'reel_{index}','file':str(path.relative_to(HOME)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[256,1024]})
"""+marker)
(HERE/'build_arcade.py').write_text(src,encoding='utf-8')
batch=(HERE.parent/'og-redesign-v1/build_batch.py').read_text().replace('build_og.py','build_arcade.py')
(HERE/'build_batch.py').write_text(batch,encoding='utf-8')
print('Prepared Arcade builder')
