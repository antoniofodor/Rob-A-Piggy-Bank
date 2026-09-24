def flat(name,rgb,emission=0,metal=0,rough=.6):
 m=mat(name,rgb,metal,emission);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=rough;return m
exec(compile((HERE/'paint_helpers.py').read_text(),str(HERE/'paint_helpers.py'),'exec'))

def paint(mode):
 p=Paint('V3 tailored '+mode,(117,28,49));o=p.op;x,y,z=p.x,p.y,p.z
 def mul(a,b):return o('MULTIPLY',a,b)
 def add(a,b):return o('ADD',a,b)
 def sub(a,b):return o('SUBTRACT',a,b)
 def abs_(a):return o('ABSOLUTE',a)
 def less(a,b):return o('LESS_THAN',a,b)
 def greater(a,b):return o('GREATER_THAN',a,b)
 theta=o('ARCTAN2',y,x);lat=o('ARCTAN2',z,o('SQRT',add(mul(x,x),mul(y,y))))
 if mode=='body':
  # Restrained diamond jacquard beneath the larger gold flourishes.
  u=mul(theta,4.2);v=mul(lat,4.8)
  a=abs_(sub(o('FRACT',u),.5));b=abs_(sub(o('FRACT',v),.5));d=add(a,b)
  weave=mul(greater(d,.43),less(d,.47))
  p.color=p.mix((105,22,44),(142,43,64),weave)
  # A swept double gold band wraps the full lower body.
  sweep=add(-.30,mul(o('SINE',mul(theta,3)),.13))
  band=less(abs_(sub(z,sweep)),.030)
  band=o('MAXIMUM',band,less(abs_(sub(z,sub(sweep,.086))),.009))
  # Alternating clean stars and faceted diamonds on the flanks and rear.
  u=add(mul(theta,2.7),.15);v=mul(lat,2.7)
  a=sub(o('FRACT',u),.5);b=sub(o('FRACT',v),.5)
  angle=o('ARCTAN2',b,a);radius=o('SQRT',add(mul(a,a),mul(b,b)))
  phase=o('MODULO',add(angle,math.tau+math.pi/2),math.tau/5)
  folded=o('MINIMUM',phase,sub(math.tau/5,phase))
  star_edge=o('DIVIDE',.20*.085*math.sin(math.pi/5),add(mul(o('COSINE',folded),.085*math.sin(math.pi/5)),mul(o('SINE',folded),.20-.085*math.cos(math.pi/5))))
  star=less(radius,star_edge)
  diam=less(add(abs_(a),abs_(b)),.205)
  parity=o('MODULO',add(o('FLOOR',u),o('FLOOR',v)),2)
  motif=o('MAXIMUM',mul(star,less(parity,.5)),mul(diam,greater(parity,.5)))
  # Leave a calmer face around the eyewear and snout.
  motif=mul(motif,o('MAXIMUM',greater(y,-.67),greater(abs_(x),.64)))
  gold_mask=o('MAXIMUM',band,motif)
  p.color=p.mix(p.color,(231,173,60),gold_mask);p.metal=add(.13,mul(gold_mask,.59));p.rough=sub(.41,mul(gold_mask,.11))
 elif mode=='snout':
  p.color=p.rgb((247,226,171));p.metal=.12;p.rough=.32
 elif mode=='legs':
  stripe=mul(greater(z,-.86),less(z,-.78))
  p.color=p.mix((223,166,54),(104,22,42),stripe);p.metal=sub(.67,mul(stripe,.4));p.rough=.29
 elif mode=='ear':
  p.color=p.rgb((234,184,82));p.metal=.52;p.rough=.34
 elif mode=='ear_outer':
  p.color=p.rgb((117,28,49));p.metal=.16;p.rough=.35
 else:
  stripe=less(abs_(o('SINE',mul(z,20))),.22)
  p.color=p.mix((222,164,51),(120,27,45),stripe);p.metal=.55;p.rough=.3
 return p.finish()

for name,mode in [('Body','body'),('Snout','snout'),('Legs','legs'),('Tail','tail')]:
 parts[name].data.materials.clear();parts[name].data.materials.append(paint(mode))
 for f in parts[name].data.polygons:f.material_index=0
with bpy.data.libraries.load(str(ROOT/'assets/piggies/common/cow/source/cow_closed.blend'),link=False) as (a,b):b.objects=['Ears']
ear=b.objects[0];indices=[p.material_index for p in ear.data.polygons];bpy.data.objects.remove(ear,do_unlink=True)
parts['Ears'].data.materials.clear();parts['Ears'].data.materials.append(paint('ear_outer'));parts['Ears'].data.materials.append(paint('ear'))
for f,i in zip(parts['Ears'].data.polygons,indices):f.material_index=min(i,1)

# Bake portable PBR maps into the original body and shared trim UV layouts.
new_textures=[];sheet=HOME/'sheets/jackpot-v3';sheet.mkdir(exist_ok=True)
scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=12
for group,objects in {'body':[parts['Body']],'trim':[parts[n] for n in ('Snout','Ears','Legs','Tail')]}.items():
 mats={m for obj in objects for m in obj.data.materials};images={}
 for kind,node_name in [('color','BAKE_COLOR'),('metal','BAKE_METAL'),('rough','BAKE_ROUGH')]:
  im=bpy.data.images.new('Jackpot_v3_'+group+'_'+kind,1024,1024,alpha=True)
  if kind!='color':im.colorspace_settings.name='Non-Color'
  for m in mats:
   nt=m.node_tree;out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');nt.links.new(nt.nodes[node_name].outputs[0],out.inputs['Surface'])
   node=nt.nodes.new('ShaderNodeTexImage');node.image=im;nt.nodes.active=node
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.bake(type='EMIT')
  pix=np.empty(1024*1024*4,dtype=np.float32);im.pixels.foreach_get(pix);pix[3::4]=1;im.pixels.foreach_set(pix)
  file=sheet/f'jackpot_v3_{group}_{kind}.png';im.filepath_raw=str(file);im.file_format='PNG';im.save();im.pack();images[kind]=im
  new_textures.append({'role':group+'_'+kind,'file':str(file.relative_to(HOME)),'size':[1024,1024],'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
 baked=mat('V3 baked '+group,(255,255,255));nt=baked.node_tree;bs=nt.nodes['Principled BSDF']
 for kind,socket in [('color','Base Color'),('metal','Metallic'),('rough','Roughness')]:
  tex=nt.nodes.new('ShaderNodeTexImage');tex.image=images[kind];nt.links.new(tex.outputs['Color'],bs.inputs[socket])
 for obj in objects:
  obj.data.materials.clear();obj.data.materials.append(baked)
  for f in obj.data.polygons:f.material_index=0
