import bpy,bmesh,json
from pathlib import Path
home=Path(r'C:/Users/anton/robloxGame/assets/piggies/legendary/finalboss')
bpy.ops.wm.open_mainfile(filepath=str(home/'package/spellcaster-v5/finalboss-spellcaster-v5.blend'))
o=bpy.data.objects['MageHoodCloth'];bm=bmesh.new();bm.from_mesh(o.data);todo=set(bm.verts);components=0
while todo:
 components+=1;stack=[todo.pop()]
 while stack:
  v=stack.pop()
  for e in v.link_edges:
   other=e.other_vert(v)
   if other in todo:todo.remove(other);stack.append(other)
chi=len(bm.verts)-len(bm.edges)+len(bm.faces)
assert components==1 and all(e.is_manifold for e in bm.edges)
print('HOOD_TOPOLOGY',components,'component','Euler',chi)
bm.free()
p=home/'package/spellcaster-v5/asset-report.json';r=json.loads(p.read_text());r['validationHood'].update(connectedComponents=components,eulerCharacteristic=chi,allEdgesManifold=True);r['tierRules']['geometry']='lined mage hood with real ear openings, continuous robe, full boots, gem shields and rear focus ring';p.write_text(json.dumps(r,indent=2)+'\n')
