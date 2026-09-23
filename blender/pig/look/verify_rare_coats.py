"""Check delivered rare colour/mask pairs with the existing hard-edge test."""
from pathlib import Path
import sys,json,hashlib
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from rare_coats import SPECS
import paths,check_fade
import numpy as np
from PIL import Image
rows=[]
for key in SPECS:
    package=Path(paths.animal_package(key))
    colors=[package/f'{key}_{group}_color.png' for group in ('body','trim')]
    palette=check_fade._palette(np.concatenate([np.asarray(Image.open(p).convert('RGB'),dtype=np.int16).reshape(-1,1,3) for p in colors]))
    for group,color in zip(('body','trim'),colors):
        image=Image.open(color);assert image.size==(1024,1024)
        assert np.asarray(image.convert('RGBA'))[:,:,3].min()==255,(key,group,'alpha')
        off,fade,_=check_fade.measure(color,palette);assert fade<=check_fade.FAIL,(key,group,fade)
        mask=package/f'{key}_{group}_emissive.png';a=np.asarray(Image.open(mask).convert('RGB'))
        assert a.shape==(1024,1024,3) and np.array_equal(a[:,:,0],a[:,:,1]) and np.array_equal(a[:,:,0],a[:,:,2]),mask
        coverage=float((a[:,:,0]>127).mean());assert 0<coverage<.15,(mask,coverage)
        assert hashlib.sha256(mask.read_bytes()).digest()==hashlib.sha256(Path(paths.skin_emissive(key,group)).read_bytes()).digest()
        rows.append(dict(skin=key,group=group,broadFadePercent=round(float(fade),5),emissiveSheetPercent=round(coverage*100,3)))
out=ROOT.parents[1]/'assets/skins/animal/rare';out.mkdir(parents=True,exist_ok=True)
(out/'texture-checks.json').write_text(json.dumps(rows,indent=2))
print('RARE_TEXTURES_VERIFIED',len(rows),'opaque colour sheets and grayscale emissive masks; hard-edge tests passed')
