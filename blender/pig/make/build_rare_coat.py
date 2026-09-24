"""Derive rare coats from the approved procedural graphs without changing parents.

Blender -b --python make/build_rare_coat.py -- --skin strawberrycow
Then bake_skin.py and package_animal.py --skin ID --name NAME.
"""
from pathlib import Path
import sys,json,hashlib
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import bpy,paths
from rare_coats import SPECS
args=sys.argv[sys.argv.index('--')+1:];key=args[args.index('--skin')+1];spec=SPECS[key]
source=Path(paths.skin_blend(spec['parent']));source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
def rgba(rgb):
    return tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)+(1,)
def labeled(nt,label):
    found=[n for n in nt.nodes if n.label==label]
    assert len(found)==1,(key,label,len(found))
    return found[0]
def paint(nt,label,side,color):
    node=labeled(nt,label)
    socket=node.inputs[side] if node.bl_idname=='ShaderNodeMixRGB' else [s for s in node.inputs if s.type=='RGBA'][side-1]
    socket.default_value=rgba(color)
def mix(nt,a,b,fac,label):
    n=nt.nodes.new('ShaderNodeMixRGB');n.label=label
    nt.links.new(a,n.inputs[1]);n.inputs[2].default_value=rgba(b);nt.links.new(fac,n.inputs[0]);return n.outputs[0]
materials={m for name in ('Body','Snout','Ears','Legs','Tail') for m in bpy.data.objects[name].data.materials if m}
tweaks_applied={}
for mat in materials:
    original_name=mat.name;mat.name=original_name.replace(spec['parent'],key)
    nt=mat.node_tree;bsdf=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    if not bsdf.inputs['Base Color'].is_linked:
        bsdf.inputs['Base Color'].default_value=rgba(spec['ear'] if 'ear' in original_name else spec['nose'])
        continue
    if key == 'honeycomb':
        import runpy
        pattern = Path(paths.skin_dir(key)) / 'generate/honeycomb_pattern.py'
        runpy.run_path(str(pattern))['paint'](nt, bsdf, spec)
        continue
    parent=spec['parent']
    if parent=='cow':
        paint(nt,'white -> the muzzle pad',1,spec['base']);paint(nt,'white -> the muzzle pad',2,spec['nose'])
        paint(nt,'lay the blotches on',2,spec['ink'])
    elif parent=='tiger':
        paint(nt,'orange -> cream belly',1,spec['base']);paint(nt,'orange -> cream belly',2,spec['pale'])
        paint(nt,'nose pad back to orange',2,spec['nose']);paint(nt,'lay the ink on',2,spec['ink'])
        # Continue Glacier/Peppermint stripes to the separate solid snout.
        # The inherited angular and depth masks otherwise clear a bare collar
        # beneath it. Keep the parent scene and its common coat unchanged.
        for label in ('clean round the muzzle','clean muzzle'):
            mask=labeled(nt,label)
            mask.inputs['To Min'].default_value=1.0
            mask.inputs['To Max'].default_value=1.0
    elif parent=='leopard':
        paint(nt,'coat -> pale underside',1,spec['base']);paint(nt,'coat -> pale underside',2,spec['pale'])
        paint(nt,'the snout pad',2,spec['nose']);paint(nt,'the rosette centre',2,spec['fill']);paint(nt,'lay the petals on',2,spec['ink'])
    elif parent=='giraffe':
        paint(nt,'tan -> cream underside',1,spec['base']);paint(nt,'tan -> cream underside',2,spec['pale'])
        paint(nt,'the snout pad',2,spec['nose']);paint(nt,'lay the patches on',2,spec['ink'])
    elif parent=='ladybird':
        paint(nt,'red -> black',1,spec['base']);paint(nt,'red -> black',2,spec['ink'])
        paint(nt,'and the cheek patches on top',2,spec['pale'])
        # Keep the seed field; remove the insect's black head/wing seam.
        mark=labeled(nt,'BLACK HERE');nt.links.remove(mark.inputs[0].links[0]);mark.inputs[0].default_value=0
        belly=labeled(nt,'THE UNDERSIDE AND THE LEGS').outputs[0]
        color=bsdf.inputs['Base Color'].links[0].from_socket
        flesh=mix(nt,color,spec['pale'],belly,'hard watermelon flesh')
        seeds=labeled(nt,'THE SPOTS').outputs[0]
        color=mix(nt,flesh,spec['ink'],seeds,'black seeds over rind and flesh')
        nt.links.new(color,bsdf.inputs['Base Color'])
    # A COAT MAY RETUNE ITS PARENT'S FIELD AS WELL AS REPAINT IT, and the
    # difference is what separates a recoloured animal from a different
    # object. Patched proved it: the giraffe's palette swapped fine and the
    # render was a terracotta GIRAFFE, because the thing that says "animal"
    # is not the colour, it is that the lanes are wide, uneven and wandering.
    # A seam is thin and even. `tweaks` is (label, input, value) triples set
    # on the parent's own labelled nodes, so a spec can move the FIELD
    # without a second generator and without touching the parent scene.
    #
    # Applied across every material and asserted to have landed at least
    # once GLOBALLY rather than per material: a label like 'this cell's own
    # gap' lives on the body graph and legitimately does not exist on the
    # flat snout, so a per-material assert would fire on a correct spec --
    # while a typo still cannot pass, which is the half that matters.
    for label, socket, value in spec.get('tweaks', ()):
        for node in (n for n in nt.nodes if n.label == label):
            node.inputs[socket].default_value = value
            tweaks_applied[(label, socket)] = tweaks_applied.get((label, socket), 0) + 1

    # THE SPARSE HIGHLIGHT SPECKLES ARE RETIRED, AND THEY WERE ONE FEATURE
    # WEARING TWO CHANNELS. A Voronoi island field mixed pale dots into the
    # BASE COLOUR -- so they baked into the colour sheet and showed on the
    # animal -- and the same mask was baked again as a grayscale
    # `<skin>_<group>_emissive.png`.
    #
    # THE EMISSIVE HALF WAS LIVE, AND I NEARLY RECORDED THAT IT WAS NOT.
    # `PiggyModel` says beside the shard glow that *a surface pack has no
    # emissive channel*, and `Config.SURFACE_PACKS` rows carry `template`
    # and `trimTemplate` and no third map -- so on both of those the sheet
    # looked like dead output. It is not: a pack is a CLONED
    # `SurfaceAppearance`, and the real wiring is in
    # `src/ReplicatedStorage/Shared/SurfacePacks/<name>.model.json`, where
    # fourteen of them carried `EmissiveMaskContent` at an uploaded asset id
    # with `EmissiveStrength` 0.8. The speckles GLOWED in the shipped game.
    #
    # A COMMENT IS NOT A MEASUREMENT, and the model.json was the
    # measurement. Two separate sources agreed with each other and with a
    # plausible story, and the thing that settled it was opening the file
    # that actually ships.
    #
    # THE 0.8 IS WHAT TELLS THE TWO APART, and it is worth keeping because
    # the packs are otherwise identical in shape. The five `legend_*` packs
    # carry an emissive map at 0.35 -- the dragon's burning seams, the
    # stormwolf's lightning -- which is a designed feature from a different
    # pipeline and must never be cleared with these. Every 0.8 was this
    # builder's, because `coat-spec.json` wrote `emissiveStrength=.8`.
    #
    # WHAT IS LOST, STATED PLAINLY: a coat is flat colour now, with no tonal
    # break across the back and shoulders. If one ever wants that again it
    # belongs in the COAT'S OWN FIELD -- the generator already draws cells,
    # lanes and belly masks that a highlight could ride -- rather than as a
    # second unrelated noise laid over every skin in the catalogue at once.
    bsdf.inputs['Roughness'].default_value=.82
for label, socket, _ in spec.get('tweaks', ()):
    assert tweaks_applied.get((label, socket)), (key, 'tweak never landed', label, socket)
# A single muzzle colour also covers the dimple floors. Reusing the parent's
# full body field here leaves pale spots inside the nostrils (fixed on Tiger).
snout_mat=bpy.data.materials.new(key+'_snout');snout_mat.use_nodes=True
snout_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=rgba(spec['nose'])
snout_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
snout=bpy.data.objects['Snout']
for i in range(len(snout.data.materials)):snout.data.materials[i]=snout_mat
if key == 'honeycomb':
    import runpy
    runpy.run_path(str(Path(paths.skin_dir(key)) / 'generate/honey_tail.py'))['apply'](bpy.data.objects['Tail'])
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=paths.skin_blend(key))
Path(paths.coat_spec(key)).write_text(json.dumps(dict(spec,skin=key,rarity='rare',parentScene=str(source),parentSceneSha256=source_hash,glow='None. Flat baked colour; no emissive channel, no animation, no extra geometry'),indent=2))
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash
print('RARE_COAT_AUTHORED',key,flush=True)
