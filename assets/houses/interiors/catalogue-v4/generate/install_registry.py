"""Register generated kits without changing saves, house IDs or progression rules."""
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[3]
rows=json.loads((ROOT/'manifest.json').read_text())
entries='\n'.join('\t'+row['id']+' = "'+row['kit']+'",' for row in rows)
for rel,header in [
    ('src/ReplicatedStorage/Shared/Config.luau','Config.HOUSE_INTERIOR_KITS = {'),
    ('src/ServerScriptService/Services/ThemedInterior.luau','local KITS_FALLBACK: { [string]: string } = {')]:
    path=REPO/rel; source=path.read_text(encoding='utf-8')
    start=source.index(header); end=source.index('\n}',start)+2
    old=source[start:end]
    ids={row['id'] for row in rows}
    extra=[(id,kit) for id,kit in re.findall(r'(\w+)\s*=\s*"([^"]+InteriorKit)"',old) if id not in ids]
    suffix=''.join('\n\t'+id+' = "'+kit+'",' for id,kit in extra)
    path.write_text(source[:start]+header+'\n'+entries+suffix+'\n}'+source[end:],encoding='utf-8')
path=REPO/'default.project.json'; project=json.loads(path.read_text())
for row in rows:
    project['tree']['ServerStorage'][row['kit']]={'$path':f'assets/houses/interiors/catalogue-v4/{row["slug"]}/{row["slug"]}-interior-kit.rbxmx'}
path.write_text(json.dumps(project,indent=2)+'\n')
print('Registered',len(rows),'permanent house interiors')
