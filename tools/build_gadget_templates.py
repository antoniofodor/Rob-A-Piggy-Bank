"""Write src/ReplicatedStorage/Shared/GadgetTemplates/<style>.rbxmx from a Studio import.

python tools/build_gadget_templates.py

Reads assets/shop-ui/icon-system-v1/models/gadget-imports.json, which is
captured from Studio after the plunger and bubblegum-bomb FBX files have been
brought in with the 3D Importer (see tools/capture_gadget_imports.luau). Each
part is already expressed in the gadget's AUTHORED frame -- plunger handle +Y,
cup -Y, rim 1.32 below the origin; gum centred on the ball -- which is the
frame GadgetModel's flight, grip and stuck-plunger maths assume.

Same shape as blender/guards/build_runtime_assets.py: the mesh ids live in a
reproducible template in source control, never only in the place file.
"""
import json
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, indent, tostring

ROOT = Path(__file__).resolve().parents[1]
imports = json.loads((ROOT / 'assets/shop-ui/icon-system-v1/models/gadget-imports.json').read_text())
out = ROOT / 'src/ReplicatedStorage/Shared/GadgetTemplates'
out.mkdir(parents=True, exist_ok=True)

CF = ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22')


def prop(p, typ, name, val):
    e = SubElement(p, typ, name=name)
    if isinstance(val, dict):
        for k, v in val.items():
            SubElement(e, k).text = str(v)
    else:
        e.text = str(val)
    return e


for style, parts in imports.items():
    root = Element('roblox', version='4')
    model = SubElement(root, 'Item', {'class': 'Model', 'referent': 'model'})
    prop(SubElement(model, 'Properties'), 'string', 'Name', style)
    for i, part in enumerate(parts):
        item = SubElement(model, 'Item', {'class': 'MeshPart', 'referent': f'p{i}'})
        p = SubElement(item, 'Properties')
        prop(p, 'string', 'Name', part['name'])
        prop(p, 'Content', 'MeshId', {'url': part['mesh']})
        if part.get('texture'):
            prop(p, 'Content', 'TextureID', {'url': part['texture']})
        prop(p, 'Vector3', 'size', dict(zip('XYZ', part['size'])))
        prop(p, 'Vector3', 'InitialSize', dict(zip('XYZ', part['meshSize'])))
        prop(p, 'CoordinateFrame', 'CFrame', dict(zip(CF, part['cf'])))
        # The palette texture carries every colour; the importer's default
        # grey under it would only show through a gap, so it goes white.
        r, g, b = (255, 255, 255) if part.get('texture') else part['color']
        prop(p, 'Color3uint8', 'Color3uint8', (r << 16) | (g << 8) | b)
        prop(p, 'token', 'Material', 272)  # SmoothPlastic, like every other gadget part
        for n in ('Anchored',):
            prop(p, 'bool', n, 'true')
        for n in ('CanCollide', 'CanTouch', 'CanQuery', 'CastShadow'):
            prop(p, 'bool', n, 'false')
    indent(root)
    (out / f'{style}.rbxmx').write_text(tostring(root, encoding='unicode'))
    print(f'GadgetTemplates/{style}.rbxmx: {len(parts)} parts')
