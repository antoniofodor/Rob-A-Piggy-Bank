from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
preview=ROOT/'assets/piggies/legendary/finalboss/preview/overdrive-v3'
for label in ('motion','reactor'):
 paths=sorted((preview/'frames').glob(label+'-*.png'));assert len(paths)==24,(label,len(paths))
 frames=[Image.open(p).convert('RGB') for p in paths]
 dest=preview/f'finalboss-v3-{label}.webp'
 frames[0].save(dest,save_all=True,append_images=frames[1:],duration=250,loop=0,quality=88,method=6)
 with Image.open(dest) as im:assert im.n_frames==24
 print(dest.name,dest.stat().st_size)
