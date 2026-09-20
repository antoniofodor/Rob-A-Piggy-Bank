"""Bake a cyan-only emission mask through the unchanged coat UVs."""
import bpy,hashlib,json
import numpy as np
from stormwolf_lightning import values,constant_keys

def attach(body,coat,color,out):
    nt=coat.node_tree
    def math_node(op,a,b):
        n=nt.nodes.new('ShaderNodeMath');n.operation=op
        for i,value in enumerate((a,b)):
            if isinstance(value,(int,float)):n.inputs[i].default_value=value
            else:nt.links.new(value,n.inputs[i])
        return n.outputs[0]
    def ramp(socket,low,high):
        n=nt.nodes.new('ShaderNodeMapRange');n.clamp=True
        nt.links.new(socket,n.inputs['Value']);n.inputs['From Min'].default_value=low;n.inputs['From Max'].default_value=high
        return n.outputs['Result']
    rgb=nt.nodes.new('ShaderNodeSeparateColor');rgb.mode='RGB';nt.links.new(color.outputs['Color'],rgb.inputs['Color'])
    # Cyan saturation rejects the neutral silver mane. Brightness rejects the
    # dark blue body, even though it shares the same hue as the lightning.
    saturation=math_node('DIVIDE',math_node('SUBTRACT',rgb.outputs['Green'],rgb.outputs['Red']),math_node('ADD',rgb.outputs['Green'],.0001))
    mask=math_node('MULTIPLY',ramp(saturation,.35,.65),ramp(rgb.outputs['Green'],.055,.30))
    output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');surface=output.inputs['Surface'].links[0].from_socket
    emission=nt.nodes.new('ShaderNodeEmission');nt.links.new(mask,emission.inputs['Color']);nt.links.new(emission.outputs[0],output.inputs['Surface'])
    image=bpy.data.images.new('StormWolf_LightningMask',1024,1024,alpha=False);image.colorspace_settings.name='Non-Color'
    target=nt.nodes.new('ShaderNodeTexImage');target.image=image;target.label='Body lightning emission mask';nt.nodes.active=target
    bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=2;scene.render.bake.use_selected_to_active=False
    bpy.ops.object.bake(type='EMIT')
    path=out/'stormwolf_body_emissive.png';image.filepath_raw=str(path);image.file_format='PNG';image.save();image.pack()
    pixels=np.asarray(image.pixels[:]).reshape(-1,4)
    assert np.max(np.abs(pixels[:,0]-pixels[:,1]))<1e-6 and np.max(np.abs(pixels[:,1]-pixels[:,2]))<1e-6
    coverage=float((pixels[:,0]>.1).mean());assert .001<coverage<.15,coverage
    nt.links.new(surface,output.inputs['Surface']);nt.nodes.remove(emission)
    principled=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    nt.links.new(color.outputs['Color'],principled.inputs['Emission Color'])
    pulse=nt.nodes.new('ShaderNodeValue');pulse.label='Painted lightning pulse'
    nt.links.new(math_node('MULTIPLY',target.outputs['Color'],pulse.outputs[0]),principled.inputs['Emission Strength'])
    for frame in range(1,62):
        pulse.outputs[0].default_value=.35+4.65*max(values(1 if frame==61 else frame))
        pulse.outputs[0].keyframe_insert('default_value',frame=frame)
    constant_keys(nt)
    report=dict(file=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),size=[1024,1024],coverageAboveTenPercent=coverage,
        selection='Cyan saturation and brightness; neutral mane and dark coat excluded',idleStrength=.35,peakStrength=5.0)
    (out/'body-glow-checks.json').write_text(json.dumps(report,indent=2));print('BODY_GLOW_MASK',json.dumps(report),flush=True)
    return report
