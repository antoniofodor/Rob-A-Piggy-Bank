"""Use the imported mesh frame, rather than the opposite-facing seat frame."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
HOME=ROOT/'assets/piggies/legendary/supernova/package'
data=json.loads((HOME/'imported-placement.json').read_text())
p=ROOT/'src/ReplicatedStorage/Shared/Config.luau';s=p.read_text()
a=s.index('\tsupernova = {',s.index('Config.SKIN_ACCESSORIES = {'));b=s.index('\n\t},',a)+4
row=s[a:b]
for part in data:
 name=part['name'];offset=[v/100 for v in part['cf'][:3]]
 pattern=r'(part = "'+re.escape(name)+r'",.*?offset = )Vector3.new\([^)]*\)'
 row,count=re.subn(pattern,lambda m:m[1]+'Vector3.new('+', '.join(f'{v:.8f}' for v in offset)+')',row,flags=re.S)
 assert count==1,name
p.write_text(s[:a]+row+s[b:])
(HOME/'placement-patch.json').write_text(json.dumps({'row':row,'parts':data,'reason':'Original offsets used (x,z,-y), but imported meshes and body-local accessory frame use (-x,z,y). Preserve imported orientation and use imported centers/100.'},indent=2))
print('Corrected all 12 Supernova flame/cinder offsets to imported model centers.')
