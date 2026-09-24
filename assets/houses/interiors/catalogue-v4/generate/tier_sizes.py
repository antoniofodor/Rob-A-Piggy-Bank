"""Scale architecture by catalogue tier; keep stations and player interactions human-sized."""
import json
import re
from pathlib import Path
from transforms import scale_part

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[3]

def tier_order():
    config=(REPO/'src/ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf-8')
    block=config.split('Config.HOUSE_TIERS = {',1)[1].split('\n}',1)[0]
    return re.findall(r'\bid\s*=\s*"([^"]+)"',block)

def dimensions(id):
    rank=tier_order().index(id)
    cfg=json.loads((ROOT/'tier-sizing.json').read_text())
    return dict(tier=rank+1,width=cfg['baseWidth']+rank*cfg['widthPerTier'],
        length=cfg['baseLength']+rank*cfg['lengthPerTier'],height=cfg['baseHeight']+rank*cfg['heightPerTier'])

def apply(templates,dims):
    width,length,height=dims['width'],dims['length'],dims['height']
    for name,template in templates.items():
        if name=='Pedestal': continue
        scale=(width/60,height/32,length/40 if name=='RoomShell' else 1)
        for part in template['parts']: scale_part(part,scale)
        for mount in template['mounts'].values():
            mount['position']=[v*s for v,s in zip(mount['position'],scale)]
        if name=='RoomShell':
            template['length']=length
            for key,mount in template['mounts'].items():
                if key.startswith('Slot_'):
                    mount['position'][0]=(-1 if mount['position'][0]<0 else 1)*(width/2-12)
                    mount['position'][1]=.03
