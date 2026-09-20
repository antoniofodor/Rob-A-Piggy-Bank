"""Read-only PNG inspection and layout manifest generation. Does not alter images."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RECTS = {
    'lock-housing': [33, 105, 1470, 799],
    'pin-active': [268, 72, 491, 1405],
    'pin-idle': [268, 72, 491, 1405],
    'pin-set': [268, 72, 491, 1405],
    'spring': [254, 109, 517, 1319],
    'top-cap': [92, 296, 1065, 685],
    'target-notch': [31, 330, 1474, 361],
    'success-check': [188, 202, 878, 849],
    'button-primary': [31, 259, 1474, 487],
    'button-primary-pressed': [31, 259, 1474, 487],
    'button-secondary': [41, 272, 1455, 455],
    'button-secondary-pressed': [41, 272, 1455, 455],
}
assets = {}
for name, rect in RECTS.items():
    path = ROOT / 'sprites' / f'{name}.png'
    im = Image.open(path)
    assert im.mode == 'RGBA', (name, im.mode)
    alpha = im.getchannel('A')
    assert alpha.getextrema()[0] == 0, name
    x, y, w, h = rect
    assert 0 <= x < x+w <= im.width and 0 <= y < y+h <= im.height
    assets[name] = {
        'file': f'sprites/{name}.png',
        'sourceSize': list(im.size),
        'displayRectPixels': rect,
        'displayRectNormalized': [round(x/im.width, 7), round(y/im.height, 7), round(w/im.width, 7), round(h/im.height, 7)],
        'alphaRange': list(alpha.getextrema()),
        'transparentPixelFraction': round(alpha.histogram()[0] / (im.width * im.height), 4),
    }
manifest = {
    'version': 1,
    'units': 'Layer dimensions and positions are fractions of the displayed housing, after its display rect is applied.',
    'generation': 'Built-in image_gen; original PNG alpha preserved; no pixel editing.',
    'assets': assets,
    'layout': {
        'housingAspectRatio': 1470/799,
        'channelCentersX': [0.145, 0.322, 0.499, 0.676, 0.853],
        'channelVisibleY': [0.16, 0.80],
        'cap': {'width': 0.068, 'height': 0.080, 'top': 0.17, 'z': 4},
        'pin': {'width': 0.060, 'height': 0.316, 'topRange': [0.30, 0.48], 'collarCenterYWithinPin': 0.50, 'z': 5},
        'spring': {'width': 0.039, 'top': 0.234, 'bottom': 'pin.top + 0.006', 'z': 3},
        'notch': {'width': 0.106, 'height': 0.062, 'centerY': 0.55, 'z': 2},
        'success': {'width': 0.049, 'height': 0.088, 'centerY': 'pin.top + pin.height * 0.50', 'z': 6},
        'numberCenterY': 0.905,
        'samplePinTops': [0.392, 0.392, 0.35, 0.48, 0.48],
    },
    'integrationStatus': 'Art only. Not uploaded to Roblox. No asset IDs, runtime wiring, or in-game validation.'
}
(ROOT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
(ROOT/'manifest.js').write_text('window.PIN_PACK = '+json.dumps(manifest)+';\n', encoding='utf-8')
print(f'Validated {len(assets)} RGBA sprites; all contain transparent pixels. Wrote manifest.json.')
