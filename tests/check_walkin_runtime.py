"""Offline runtime-template regression: baked scale, glass and door markers."""
import contextlib,io,json,runpy,sys,tempfile
from pathlib import Path
from xml.etree import ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'assets/houses/tools'))
old_argv=sys.argv;sys.argv=['build_house_runtime.py','modern','2']
module=runpy.run_path(str(ROOT/'assets/houses/tools/build_house_runtime.py'),run_name='walkin_test')
sys.argv=old_argv
with tempfile.TemporaryDirectory(prefix='walkin-runtime-') as temp:
    base=Path(temp);asset=base/'fixture';asset.mkdir()
    # Importer uses 40 units per stud; source is already the approved final size.
    geometry={'boundsBlender':{'min':[-10,-2,0],'max':[10,20,16],'size':[20,22,16]},
      'collisionBoxesDraft':[{'name':'Floor','blenderLocation':[0,9,.25],'sizeXYZ':[20,22,.5]}],
      'mountsBlender':{'Wall':[0,19.8,4.5]},'mountYawBlender':{'Wall':180},
      'walkIn':{'bakedExteriorScale':1.31,'runtimeDisplayScale':1,'doors':[
        {'name':'HouseDoorLeaf_L','hingeBlender':[-3,-2,.5],'openDegrees':-100},
        {'name':'HouseDoorLeaf_R','hingeBlender':[3,-2,.5],'openDegrees':100}]}}
    parts=[{'name':n,'mesh':'rbxassetid://0','meshSize':[800,640,880],'position':[0,320,360]} for n in ('Dome_DomeGlass.001','Pod_Pod','HouseDoorLeaf_L_WalkDoor','HouseDoorLeaf_R_WalkDoor')]
    imported={'bounds':{'lo':[-400,0,-80],'hi':[400,640,800]},'groundY':0,'parts':parts}
    rows=[{'name':n.split('.')[0],'colorRGB':[100,150,170],'material':m} for n,m in zip([p['name'] for p in parts],['DomeGlass','Pod','WalkDoor','WalkDoor'])]
    for filename,data in [('geometry-report.json',geometry),('studio-import.json',imported),('roblox-import-report.json',{'meshes':rows}),('material-overrides.json',{'DomeGlass':{'RobloxTransparency':.82}})]:
        (asset/filename).write_text(json.dumps(data))
    globals_=module['main'].__globals__;globals_['ASSET']=asset;globals_['ROOT']=base
    with contextlib.redirect_stdout(io.StringIO()):module['main']()
    tree=ET.parse(base/'src/ReplicatedStorage/Shared/HouseTemplates/modern.rbxmx')
    props={p.find("string[@name='Name']").text:p for p in tree.findall('.//Item/Properties') if p.find("string[@name='Name']") is not None}
    assert float(props['Dome_DomeGlass.001'].find("float[@name='Transparency']").text)==.82
    assert float(props['Pod_Pod'].find("float[@name='Transparency']").text)==0
    assert float(props['Pod_Pod'].find("Vector3[@name='size']/X").text)==20, 'display scale applied twice'
    assert float(props['Collide_Floor'].find("Vector3[@name='size']/X").text)==20
    assert props['HouseDoorLeaf_L_WalkDoor'].find("bool[@name='CanCollide']").text=='false'
    for side in ('L','R'):
        p=props['HouseDoorHinge_'+side]
        assert float(p.find("CoordinateFrame[@name='CFrame']/Y").text)==.5
        assert p.find("bool[@name='CanCollide']").text=='false'
    angles=sorted(float(e.text) for e in tree.findall(".//double[@name='Value']"))
    assert angles==[-100,100]
print('PASS: final authored scale stays 1:1, glass survives duplicate mesh names, collision matches scale, both non-blocking door hinges carry the correct swing.')
