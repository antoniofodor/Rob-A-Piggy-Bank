"""Read back the deliverable files; verify geometry, placements and material loops."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
rows=json.loads((HERE/'design-specs.json').read_text())['skins'];results=[]
for row in rows:
    key=row['key'];home=ROOT/'assets/piggies'/row['tier']/key/'revisions/og-v2'
    report=json.loads((home/'package/og-v2-asset-report.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(home/'package'/f'{key}-og-v2.blend'))
    scene=bpy.context.scene;scene.frame_set(1)
    assert scene.get('skinKey')==key and report['baseGeometryAndUVPreserved']
    assert all(p['nonManifoldEdges']==0 and p['triangles']<20000 for p in report['parts'])
    assert all(e['roundTripChecked'] and e['roundTripBoundsError']<.001 for e in report['exports'])
    extra=[bpy.data.objects[p['name']] for p in report['parts'] if p['role']=='accessory']
    for ob in extra:
        assert ob.get('rootEmbedded')
        assert all((ob.matrix_world@v.co).z>-.3 for v in ob.data.vertices),'stone at feet'
        assert all(not(abs((ob.matrix_world@v.co).x)<.16 and -.04<(ob.matrix_world@v.co).y<.56 and (ob.matrix_world@v.co).z>.8) for v in ob.data.vertices),'coin slot blocked'
    mats={m for n in ('Body','Snout','Ears','Legs','Tail') for m in bpy.data.objects[n].data.materials}
    pulse=[];scan=[]
    for m in mats:
        node=m.node_tree.nodes.get('Six second material shimmer')
        if node:
            values=[]
            for frame in (1,37,73,109,145):scene.frame_set(frame);values.append(node.outputs[0].default_value)
            assert abs(values[0]-values[-1])<1e-5 and max(values)-min(values)>.2
            pulse.append({'material':m.name,'range':[min(values),max(values)],'loopClosed':True})
        node=m.node_tree.nodes.get('Scan position')
        if node:
            scene.frame_set(1);a=node.outputs[0].default_value
            scene.frame_set(145);b=node.outputs[0].default_value
            assert a<-1.30 and b>1.40
            scan.append({'material':m.name,'startBelowFeet':a,'endAboveEars':b,'resetHidden':True})
    if key in ('aurora','neonmint','ghost','hologram'):assert len(pulse)==2
    if key=='hologram':assert len(scan)==2
    if row['tier']=='epic':
        assert not extra and scene.get('aura')==row['aura']
        assert all(m.node_tree.nodes['Principled BSDF'].inputs['Alpha'].is_linked for m in mats)
        assert all(m.surface_render_method=='DITHERED' for m in mats)
        assert all(not m.node_tree.nodes.get('Outer visible surface only') for m in mats),'designer requested layered transparency'
    else:assert scene.get('aura')==''
    results.append({'key':key,'meshChecksPassed':True,'extraMeshes':len(extra),'extraTriangles':sum(p['triangles'] for p in report['parts'] if p['role']=='accessory'),'materialAnimation':pulse,'projectionScan':scan,'coinSlotAndFacePreserved':True})
(HERE/'validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('SAVED_ASSET_VALIDATION_PASSED',json.dumps(results),flush=True)
