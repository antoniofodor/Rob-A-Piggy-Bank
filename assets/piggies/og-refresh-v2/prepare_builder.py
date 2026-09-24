"""Freeze the validated v1 export pipeline, replacing the seven design fields."""
from pathlib import Path
HERE=Path(__file__).resolve().parent
s=(HERE.parent/'og-redesign-v1/build_og.py').read_text()
s=s.replace('og-redesign-v1','og-refresh-v2').replace('og-v1','og-v2').replace('og_v1','og_v2').replace('OG v1','OG v2')
s=s.replace('Build the 15 OG redesigns','Build the seven OG refreshes').replace('build_og.py','build.py')
s=s.replace("HOME = ROOT/'assets/piggies'/TIER/KEY", "HOME = ROOT/'assets/piggies'/TIER/KEY/'revisions/og-v2'")
s=s.replace("('BAKE_ROUGH',self.rough)","('BAKE_ROUGH',self.rough),('BAKE_ALPHA',self.opacity)")
s=s.replace("self.wire(self.glow,self.bs.inputs['Emission Strength']);", "self.wire(self.opacity,self.bs.inputs['Alpha']);self.wire(self.glow,self.bs.inputs['Emission Strength']);")
start=s.index("P=SPEC['palette'];paints={}");end=s.index('extras=[];aura=[]',start)
s=s[:start]+"exec(compile((HERE/'paint.py').read_text(),str(HERE/'paint.py'),'exec'))\n\n"+s[end:]
start=s.index("if KEY in ('rockslide','quartz'):");end=s.index('assert signatures==',start)
s=s[:start]+"exec(compile((HERE/'geometry.py').read_text(),str(HERE/'geometry.py'),'exec'))\n\n"+s[end:]
s=s.replace("channels=['color']+(['emissive'] if TIER!='rare' else [])+(['metal','rough'] if KEY=='verdigris' else [])", "channels=['color','metal','rough']+(['emissive'] if KEY in ('aurora','neonmint','ghost','hologram') else [])+(['alpha'] if TIER=='epic' else [])")
# Preserve v1's 2x bake and downsample: fine coat edges need antialiasing.
s=s.replace('size*2,size*2',"(size if KEY in ('ghost','hologram') else size*2),(size if KEY in ('ghost','hologram') else size*2)")
start=s.index('    # The review/export uses');end=s.index('\nscene.frame_set(1)\nmotion_checks={}',start)
s=s[:start]+'''    # Reconstruct the reviewed surface from the actual exported image maps.
    mat=flat(group+'_Baked',P[0],rough=.65);nt=mat.node_tree;p=nt.nodes['Principled BSDF']
    for channel,socket in [('color','Base Color'),('metal','Metallic'),('rough','Roughness'),('alpha','Alpha'),('emissive','Emission Strength')]:
        if (group,channel) not in maps:continue
        tex=nt.nodes.new('ShaderNodeTexImage');tex.image=maps[group,channel][0]
        nt.links.new(tex.outputs['Color'],p.inputs[socket])
        if channel=='color':nt.links.new(tex.outputs['Color'],p.inputs['Emission Color'])
    decorate_material(mat,group)
    for ob in objects:assign(ob,mat)

    # A portable RGBA color map accompanies the separate opacity map.
    if (group,'alpha') in maps:
        color=maps[group,'color'][0];alpha=maps[group,'alpha'][0]
        rgba=np.empty(size*size*4,dtype=np.float32);a=np.empty_like(rgba)
        color.pixels.foreach_get(rgba);alpha.pixels.foreach_get(a);rgba[3::4]=a[0::4]
        im=bpy.data.images.new(KEY+'_'+group+'_rgba',size,size,alpha=True)
        im.pixels.foreach_set(rgba);path=HOME/'sheets'/f'{KEY}_og_v2_{group}_rgba.png'
        im.filepath_raw=str(path);im.file_format='PNG';im.save();im.pack();maps[group,'rgba']=(im,path)
''' +s[end:]
s=s.replace("scene.cycles.samples=16", "scene.cycles.samples=16;scene.cycles.transparent_max_bounces=12")
s=s.replace('resolution_x=800;scene.render.resolution_y=800','resolution_x=900;scene.render.resolution_y=900')
s=s.replace("(185,187,189)", "((39,51,69) if TIER=='epic' else (166,176,189))")
s=s.replace("world.node_tree.nodes['Background'].inputs[1].default_value=.5", "world.node_tree.nodes['Background'].inputs[1].default_value=.35 if TIER=='epic' else .5")
s=s.replace("light('Key',(-3,-4,6),370,5);light('Fill',(4,-1,3),190,4);light('Rim',(1,4,5),390,3)","light('Key',(-3,-4,6),230 if TIER=='epic' else 340,5);light('Fill',(4,-1,3),90 if TIER=='epic' else 180,4);light('Rim',(1,4,5),310,3)")
s=s.replace("shots=[('hero',(-4,-6,2.8),(0,0,.08)),('back',(-4,6,2.8),(0,0,.08))]", "shots=[('hero',(-4,-6,2.8),(0,0,.08)),('back',(-4,6,2.8),(0,0,.08)),('top',(-3,-4,6),(0,0,.08))]")
s=s.replace("'generator':'assets/piggies/og-refresh-v2/build_og.py'", "'generator':'assets/piggies/og-refresh-v2/build.py'")
s=s.replace("'materialPulse':TIER!='rare'", "'materialPulse':KEY in ('aurora','neonmint','ghost','hologram')")
s=s.replace("'runtimeNotes':'Use supplied maps", "'runtimeNotes':'Review asset, not installed. Ghost/Hologram need explicit alpha support and shader-equivalent runtime effects; see README. Use supplied maps")
(HERE/'build.py').write_text(s)
batch=(HERE.parent/'og-redesign-v1/build_batch.py').read_text().replace('build_og.py','build.py').replace("'--background','--python-exit-code'", "'--background','-t','8','--python-exit-code'")
(HERE/'build_batch.py').write_text(batch)
print('Prepared independent v2 builder')
