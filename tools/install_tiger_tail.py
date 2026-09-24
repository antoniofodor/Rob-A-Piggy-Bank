from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/piggies/legendary/rainbowtiger/revisions/tail-tip-v2'
report=json.loads((folder/'revision.json').read_text())
p=ROOT/'src/ReplicatedStorage/Shared/Config.luau'
s=p.read_text();start=s.index('\trainbowtiger = {',s.index('Config.LEGENDARIES ='))
end=s.index('\n\t},',start)+5
row=s[start:end]
for name in report['removed']:
 row=re.sub(r'^.*part = "'+re.escape(name)+r'".*\n','',row,flags=re.M)
new=[a+b for a,b in zip([-.0884,11.4737,-8.6621],report['deltaSeat'])]
row=re.sub(r'(part = "TailPlume"[^\n]*offset = )Vector3.new\([^)]*\)',lambda m:m[1]+'Vector3.new('+', '.join(f'{v:.4f}' for v in new)+')',row)
p.write_text(s[:start]+row+s[end:])
# Ruff tracks only addressed the removed meshes; tail and plume still sway together.
p=ROOT/'src/ReplicatedStorage/Shared/Legendary/Rigs.luau';s=p.read_text()
start=s.index('\trainbowtiger = {');end=s.index('\n\tphoenix = {',start)
rig=s[start:end]
rig=re.sub(r'\n\t\t\t\{ name = "Ruff_[LR]".*?parts = \{[^\n]*\} \},','',rig,flags=re.S)
p.write_text(s[:start]+rig+s[end:])
(folder/'studio-patch.json').write_text(json.dumps(dict(configRow=row,rigRow=rig,offset=new)))
print('Rainbow Tiger: removed 5 facial meshes; tail plume offset',new)
