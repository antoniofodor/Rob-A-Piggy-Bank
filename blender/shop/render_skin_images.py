"""Render animal-skin crate cards beside each skin package; never save over the blends.

blender --background --python blender/shop/render_skin_images.py [-- key key ...]

Every skin in `chest = "animal"` has a package at
assets/piggies/<tier>/<key>/package/<key>-complete.blend carrying the real body
meshes, the real coat textures and a REVIEW_Camera/REVIEW_Ground/three-light
studio. The existing <key>-hero.png is rendered from that studio onto a grey
backdrop, which a crate card cannot use: house and guardian cards are
transparent so the card's own rarity colour shows behind the artwork, and a
grey square inside a coloured card reads as a photo pasted on.

So this keeps the authored camera and lights exactly, hides the ground,
renders with a transparent film, and crops to the animal with an even margin
on a square canvas -- the same framing for all nineteen, so the shelf reads as
one set rather than nineteen photographs taken from different distances.

Output: <package>/shop-cards/<key>.png plus a sidecar .json, and
assets/shop-ui/skin-images/manifest.json. Upload ids are read back from
assets/shop-ui/skin-images/roblox-uploads.json, exactly as the guardian
script does.
"""
import bpy
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SIZE = 512          # final square card, in pixels
MARGIN = 0.02       # empty border on each side, as a fraction of SIZE -- full bleed
RENDER = 900        # the authored review resolution
SAMPLES = 64
# How wide the pig's body is on the card, as a fraction of SIZE. 0.803 is what
# the bounding-box fit gives a plain pig (411 of 512), so the fifteen skins with
# nothing sticking out come out exactly as they did before.
BODY_FRACTION = 411 / 512
# How far past the margin the whole silhouette may spill when the body rule
# would make it bigger than the card. 1.0 = everything fits.
SPILL = 1.1

config = (ROOT / 'src/ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf8')
# Keys of every skin carrying `chest = "animal"`, in catalogue order.
keys = []
current = None
for line in config.splitlines():
    m = re.match(r'^\t(\w+) = \{', line)
    if m:
        current = m.group(1)
    if 'chest = "animal"' in line and current and current not in keys:
        keys.append(current)

wanted = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if wanted:
    keys = [k for k in keys if k in wanted]


def package(key):
    hits = sorted((ROOT / 'assets/piggies').glob(f'*/{key}/package/{key}-complete.blend'))   # <tier>/<key>/
    return hits[0] if hits else None


# The parts every skin shares: a pig's body and what is bolted straight onto
# it. The body is measured on THESE alone (see `core_mask`), never on the whole
# picture. `Bolts_eyes` is the storm wolf's eyes. Anything not listed -- a
# tail, lightning, wings, plumes, crests -- is an extremity.
# Thin extremities allowed to run off the card rather than shrink the pig.
FIT_EXCLUDE = ('Lightning',)
CORE_PARTS = {'Body', 'Ears', 'Eyes', 'Legs', 'Snout', 'Bolts_eyes'}


def load_pixels(path: Path):
    image = bpy.data.images.load(str(path))
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(image)
    return px


def crop_square(src: Path, dst: Path, mask_src: Path, fit_src: Path):
    px = load_pixels(src)
    ys, xs = np.nonzero(px[:, :, 3] > 0.02)
    if len(xs) == 0:
        raise RuntimeError(f'{src.name}: render is empty')
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = max(x1 - x0, y1 - y0)
    inner = SIZE * (1 - 2 * MARGIN)
    sub = px[y0:y1, x0:x1]
    # The core-only render, same camera, cut to ITS OWN bounds: the belly band
    # is a fraction of the pig's height, not of the height of whatever is
    # standing on the pig.
    core = load_pixels(mask_src)[:, :, 3] > 0.5
    cys, cxs = np.nonzero(core)
    if len(cxs) == 0:
        raise RuntimeError(f'{mask_src.name}: core render is empty')
    cy0, cy1 = cys.min(), cys.max() + 1
    core_sub = core[cy0:cy1, x0:x1]
    # SCALED BY THE BODY, NOT THE SILHOUETTE. Fitting the whole bounding box
    # made every skin with something sticking out of it -- the storm wolf's
    # lightning, the dragon's wings, the phoenix's plumes -- a visibly smaller
    # pig than its neighbours on the same shelf. The body is the one thing all
    # nineteen share, so it is measured (the solid width across the lower
    # belly, which no wing or horn reaches) and held to the size a plain pig
    # gets from the bounding-box fit. Extremities may spill past the card edge.
    #
    # AND THE BAND IS READ OFF THE CORE PARTS ONLY. Reading it off the whole
    # silhouette was still wrong for the storm wolf: its lightning and tail sit
    # beside the body at belly height, so the "body" measured wide and the wolf
    # came out about 70% the size of every other pig on the shelf. A plain
    # pig's tail never reaches the band, so for those nothing changes.
    solid = core_sub
    h = solid.shape[0]
    # Blender images are stored bottom-up, so the belly band is the LOWER-MIDDLE
    # of the array's rows counted from the top of the picture.
    band = solid[h - int(h * 0.80):h - int(h * 0.55)]
    widths = band.sum(axis=1)
    body = float(np.median(widths[widths > 0])) if (widths > 0).any() else side
    scale = BODY_FRACTION * SIZE / body
    # Body centre column, from the same band, so the pig -- not the wings -- is centred.
    cols = np.nonzero(band.any(axis=0))[0]
    body_cx = (cols.min() + cols.max() + 1) / 2 if len(cols) else sub.shape[1] / 2
    # BUT NEVER LARGER THAN THE WHOLE ANIMAL FITS. Scaling by the body alone
    # let the legendaries' wings, spikes and plumes -- and on the wolf the body
    # itself -- run off the card, reported as cropped too much. The body rule
    # still holds wherever it fits; where it does not, the whole silhouette is
    # fitted (allowing SPILL of overhang) and centred instead.
    # The fit is measured on `fit_src`, the shot without the storm wolf's
    # lightning: a few thin bolts may run off the card, but letting them set
    # the size made the wolf's body the smallest on the shelf.
    fa = load_pixels(fit_src)[:, :, 3] > 0.02
    fys, fxs = np.nonzero(fa)
    fside = max(fxs.max() + 1 - fxs.min(), fys.max() + 1 - fys.min())
    fit = inner * SPILL / fside
    if fit < scale:
        scale = fit
        body_cx = (fxs.min() + fxs.max() + 1) / 2 - x0
    canvas = np.zeros((SIZE, SIZE, 4), dtype=np.float32)
    th, tw = max(1, round(sub.shape[0] * scale)), max(1, round(sub.shape[1] * scale))
    # Nearest-then-box resample in numpy: sample a supersampled grid and average,
    # so edges stay soft without needing PIL inside Blender.
    ss = 4
    yy = ((np.arange(th * ss) + 0.5) / (th * ss) * sub.shape[0]).astype(int).clip(0, sub.shape[0] - 1)
    xx = ((np.arange(tw * ss) + 0.5) / (tw * ss) * sub.shape[1]).astype(int).clip(0, sub.shape[1] - 1)
    big = sub[yy][:, xx]
    # Average premultiplied colour so transparent pixels do not darken edges.
    big[:, :, :3] *= big[:, :, 3:4]
    small = big.reshape(th, ss, tw, ss, 4).mean(axis=(1, 3))
    a = small[:, :, 3:4]
    small[:, :, :3] = np.where(a > 0, small[:, :, :3] / np.maximum(a, 1e-6), 0)
    # Feet on the bottom margin (row 0 is the bottom in Blender's layout), body
    # centred across; anything past the edge is clipped.
    oy = int(round((SIZE - inner) / 2))
    ox = int(round(SIZE / 2 - body_cx * scale))
    sy0, sx0 = max(0, -oy), max(0, -ox)
    cy0, cx0 = max(0, oy), max(0, ox)
    hh = min(th - sy0, SIZE - cy0)
    ww = min(tw - sx0, SIZE - cx0)
    canvas[cy0:cy0 + hh, cx0:cx0 + ww] = small[sy0:sy0 + hh, sx0:sx0 + ww]
    out = bpy.data.images.new('card', SIZE, SIZE, alpha=True)
    out.pixels.foreach_set(canvas.ravel())
    out.filepath_raw = str(dst)
    out.file_format = 'PNG'
    out.save()
    bpy.data.images.remove(out)


rows = []
for key in keys:
    source = package(key)
    if not source:
        print('SKIN_IMAGE_MISSING ' + key, flush=True)
        continue
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    ground = bpy.data.objects.get('REVIEW_Ground')
    if ground:
        ground.hide_render = True
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = RENDER
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    if scene.render.engine == 'CYCLES':
        scene.cycles.samples = SAMPLES
    raw = source.parent / 'shop-cards' / (key + '-raw.png')
    target = source.parent / 'shop-cards' / (key + '.png')
    target.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(raw)
    bpy.ops.render.render(write_still=True)
    # The same shot without the lightning, for the fit. Alpha only.
    fitshot = source.parent / 'shop-cards' / (key + '-fit.png')
    for o in scene.objects:
        if o.type == 'MESH' and o.name.startswith(FIT_EXCLUDE):
            o.hide_render = True
    if scene.render.engine == 'CYCLES':
        scene.cycles.samples = 1
    scene.render.filepath = str(fitshot)
    bpy.ops.render.render(write_still=True)
    # The same shot with only the core parts, for measuring the body. Only
    # its alpha is read, so one sample is plenty.
    core = source.parent / 'shop-cards' / (key + '-core.png')
    for o in scene.objects:
        if o.type == 'MESH' and o.name not in CORE_PARTS:
            o.hide_render = True
    if scene.render.engine == 'CYCLES':
        scene.cycles.samples = 1
    scene.render.filepath = str(core)
    bpy.ops.render.render(write_still=True)
    crop_square(raw, target, core, fitshot)
    raw.unlink()
    core.unlink()
    fitshot.unlink()
    name = re.search(r'\t' + key + r' = \{.*?name = "([^"]+)"', config, re.S).group(1)
    rows.append(dict(id=key, name=name, source=source.relative_to(ROOT).as_posix(),
                     sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                     image=target.relative_to(ROOT).as_posix(),
                     sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    print('SKIN_IMAGE ' + key, flush=True)

out = ROOT / 'assets/shop-ui/skin-images'
out.mkdir(parents=True, exist_ok=True)
uploads_file = out / 'roblox-uploads.json'
uploads = json.loads(uploads_file.read_text()) if uploads_file.exists() else {}
manifest_file = out / 'manifest.json'
previous = json.loads(manifest_file.read_text())['skins'] if manifest_file.exists() else []
merged = {row['id']: row for row in previous}
for row in rows:
    row['robloxAssetId'] = uploads.get(row['id'])
    (ROOT / row['image']).with_suffix('.json').write_text(json.dumps(row, indent=2) + '\n')
    merged[row['id']] = row
manifest_file.write_text(json.dumps(dict(size=[SIZE, SIZE], skins=list(merged.values())), indent=2) + '\n')
