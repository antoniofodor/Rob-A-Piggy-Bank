"""Generate an isolated B1 review prototype from a literal Config snapshot."""
import hashlib
import json
import re
from pathlib import Path

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
config=(ROOT/'src/ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf-8')
section=config.split('Config.HOUSE_TIERS = {',1)[1].split('\n}\n',1)[0]
# Strip Luau comments before extracting literal fields; never execute Config.
section=re.sub(r'--[^\n]*','',section)
chunks=re.split(r'\bid = "',section)[1:]
rows=[]
for chunk in chunks:
    ident=chunk.split('"',1)[0]
    def string(key):
        match=re.search(r'\b'+key+r' = "([^"]*)"',chunk)
        return match.group(1) if match else None
    def number(key):
        match=re.search(r'\b'+key+r' = (\d+)',chunk)
        return int(match.group(1)) if match else None
    price=number('cost');earned=string('earned')
    rarity=string('rarity') or ('legendary' if price>=10_000_000 else 'epic' if price>=1_000_000 else 'rare' if price>=100_000 else 'common')
    rows.append(dict(id=ident,name=string('name'),cost=price,earned=earned,rarity=rarity,
                     width=number('width'),depth=number('depth'),height=number('height'),
                     storeys=number('storeys'),blurb=string('blurb')))
assert len(rows)==19 and len({r['id'] for r in rows})==19
assert sum(r['cost'] is not None and r['cost']>0 for r in rows)==17
assert next(r for r in rows if r['id']=='goldenpig')['cost'] is None
assert not {'dragon','skyisland','raven','gardenbungalow'} & {r['id'] for r in rows}
snapshot=dict(source='src/ReplicatedStorage/Shared/Config.luau',sha256=hashlib.sha256(config.encode()).hexdigest(),
              note='Read-only registry snapshot. candy seasonal conflict unresolved; no runtime edits.',houses=rows)
(OUT/'catalogue.json').write_text(json.dumps(snapshot,indent=2)+'\n',encoding='utf-8')
theme=(ROOT/'src/ReplicatedStorage/Shared/Theme.luau').read_text(encoding='utf-8')
tokens={k:tuple(map(int,v.split(','))) for k,v in re.findall(r'Theme\.(\w+) = Color3.fromRGB\(([^)]+)\)',theme)}
css=':root{'+''.join('--'+k.lower().replace('_','-')+':#%02x%02x%02x;'%v for k,v in tokens.items())+'}'
(OUT/'theme.css').write_text('/* Resolved from Theme.luau by build.py. */\n'+css+'\n',encoding='utf-8')
gallery=(OUT/'index.html').read_text(encoding='utf-8')
for k,v in tokens.items():
    gallery=gallery.replace('#%02x%02x%02x'%v,'var(--'+k.lower().replace('_','-')+')')
if 'href="theme.css"' not in gallery:
    gallery=gallery.replace('<style>','<link rel="stylesheet" href="theme.css"><style>',1)
(OUT/'index.html').write_text(gallery,encoding='utf-8')
page=(OUT/'catalogue.template.html').read_text(encoding='utf-8').replace('__TOKENS__',css).replace('__DATA__',json.dumps(rows))
(OUT/'catalogue.html').write_text(page,encoding='utf-8')
print('Built 19 stable-ID cards; 17 priced houses and one earned goal. Runtime unchanged.')
