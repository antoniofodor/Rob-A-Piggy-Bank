import bpy,bmesh
bpy.ops.wm.open_mainfile(filepath=r'C:/Users/anton/robloxGame/assets/piggies/legendary/mechaplayer/package/arcade-v3/mechaplayer-arcade-v3.blend')
for o in bpy.data.objects:
 if 'Continuous' in o.name:
  bm=bmesh.new();bm.from_mesh(o.data)
  print('CAP',o.name,len(o.data.vertices),bm.calc_volume(signed=True),list(o.dimensions),o.matrix_world,list(o.modifiers));bm.free()
