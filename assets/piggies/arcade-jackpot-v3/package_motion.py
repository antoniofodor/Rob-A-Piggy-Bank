from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
preview=ROOT/'assets/piggies/legendary/jackpot/preview/jackpot-v3'
paths=sorted((preview/'frames').glob('payout-*.png'));assert len(paths)==72,len(paths)
frames=[Image.open(p).convert('RGB') for p in paths]
durations=[84 if i%3==2 else 83 for i in range(72)]
out=preview/'jackpot-v3-payout.webp'
frames[0].save(out,save_all=True,append_images=frames[1:],duration=durations,loop=0,quality=88,method=6)
with Image.open(out) as im:assert im.n_frames==72
print('Payout preview:',out.stat().st_size,'bytes; 72 frames; 6 seconds')
