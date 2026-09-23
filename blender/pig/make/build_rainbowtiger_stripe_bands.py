"""Rainbow Tiger: one ribbon mesh per stripe colour, so the rainbow can FLOW.

    blender.exe -b assets/piggies/legendary/rainbowtiger/package/rainbowtiger-complete.blend \
        --python blender/pig/make/build_rainbowtiger_stripe_bands.py

WHY GEOMETRY. The stripes are painted into `rainbowtiger-coat.png` in fixed
colours, and Roblox cannot recolour individual texels at run time -- an
EmissiveTint MULTIPLIES, so a red stripe can never be tinted blue. To make the
rainbow scroll down the body each band has to be its own part whose Color the
client can write, the same way the Ember Dragon's glowing pieces are parts.

THE SHAPES ARE THE PAINTED ONES, NOT A COPY OF THEM. `rainbowtiger_clean_stripes`
draws each band from a centreline and a width profile in (angle, height)
space; this rebuilds exactly those functions as a strip of quads and projects
every vertex onto the real Body along the same horizontal ray the coat's
cylindrical UV was unwrapped with. So each ribbon lies over its own painted
stripe, 0.03 studs proud (never coplanar with the coat).

Writes, beside the package:
    stripe-bands/rainbowtiger-stripe-bands.fbx   the seven meshes, one upload
    stripe-bands/bands.json                      Config.LEGENDARIES rows
    stripe-bands/preview.png                     a render with each band lit
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import tessellate_polygon

sys.path.insert(0, str(Path(__file__).resolve().parent))
ROOT = Path(__file__).resolve().parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
OUT = Path(paths.animal_package('rainbowtiger')) / 'stripe-bands'
OUT.mkdir(parents=True, exist_ok=True)

LIFT = 0.03          # studs off the coat
EDGE = 0.002         # covers the coat's anti-aliased edge, in coat z units
STEPS = 72           # along each band
ACROSS = 4           # quads across each band
# Studs between the Blender origin and Roblox's: Body centre sits 6.62 up.
GROUND = 6.62

# Exactly `rainbowtiger_clean_stripes.build_coat`'s table and knots.
BANDS = [
    ('Coral', .24, 2.28, [.86, .82, .79, .72, .73, .69, .62], .052),
    ('Orange', .27, 2.59, [.70, .65, .61, .57, .49, .32, .18], .096),
    ('Gold', .34, 2.47, [.51, .46, .43, .33, .28, .055, -.14], .101),
    ('Lime', .43, 2.36, [.30, .26, .20, .155, .045, -.19, -.36], .093),
    ('Cyan', .55, 2.24, [.075, .035, -.025, -.145, -.12, -.37, -.50], .084),
    ('Blue', .68, 2.10, [-.175, -.22, -.275, -.37, -.40, -.54, -.64], .065),
    ('Violet', .81, 1.97, [-.39, -.435, -.50, -.565, -.61, -.69, -.755], .047),
]
KNOTS = [0, .17, .36, .53, .69, .86, 1]
PROFILE_EVEN = [0, .75, 1.02, .92, 1.00, .48, 0]
PROFILE_ODD = [0, .82, .91, 1.05, .88, .42, 0]
OUTER = [(2.30, .69), (2.40, .68), (2.49, .60), (2.55, .49), (2.67, .27), (2.53, .38), (2.40, .51)]
INNER = [(2.56, .795), (2.65, .80), (2.77, .72), (2.94, .565), (2.77, .64), (2.68, .665)]
RGB = {'Coral': (231, 65, 91), 'Orange': (247, 134, 29), 'Gold': (244, 209, 42), 'Lime': (73, 214, 100),
       'Cyan': (27, 164, 238), 'Blue': (71, 101, 222), 'Violet': (157, 65, 220)}


def interp(x, xs, ys):
    if x <= xs[0]:
        return ys[0]
    for i in range(1, len(xs)):
        if x <= xs[i]:
            f = (x - xs[i - 1]) / (xs[i] - xs[i - 1])
            return ys[i - 1] + (ys[i] - ys[i - 1]) * f
    return ys[-1]


body = bpy.data.objects['Body']
assert body.matrix_world.is_identity or True
mesh = body.data
mesh.calc_loop_triangles()
verts = [body.matrix_world @ v.co for v in mesh.vertices]
tris = [tuple(t.vertices) for t in mesh.loop_triangles]
tree = BVHTree.FromPolygons(verts, tris, all_triangles=True)

# The coat UV was unwrapped on the unit pig; this file is in studs. Measure the
# factor rather than assume it: v = (z_unit + 1) / 2 on every vertex.
uv = mesh.uv_layers.get('TigerCoatUV') or mesh.uv_layers.active
ratios = []
for loop in mesh.loops[:4000]:
    z = verts[loop.vertex_index].z
    vv = uv.data[loop.index].uv[1]
    if abs(vv * 2 - 1) > 0.2:
        ratios.append(z / (vv * 2 - 1))
UNIT = sorted(ratios)[len(ratios) // 2]
print('STUDS_PER_COAT_UNIT', round(UNIT, 4), 'spread', round(max(ratios) - min(ratios), 4))


def project(angle, zc, side):
    """(coat angle, coat height, side) -> a point just proud of the Body."""
    d = Vector((side * math.sin(angle), math.cos(angle), 0))
    origin = d * 30 + Vector((0, 0, zc * UNIT))
    hit, normal, _, _ = tree.ray_cast(origin, -d, 60)
    assert hit is not None, ('missed', angle, zc, side)
    if normal.dot(d) < 0:
        normal = -normal
    return hit + normal * LIFT, normal


def build(name, pieces):
    """pieces: list of (verts, faces, outward-normals-per-vert)."""
    vv, ff = [], []
    for pv, pf, pn in pieces:
        base = len(vv)
        for f in pf:
            a, b, c = pv[f[0]], pv[f[1]], pv[f[2]]
            n = (b - a).cross(c - a)
            out = pn[f[0]] + pn[f[1]] + pn[f[2]]
            ff.append(tuple(base + i for i in (f if n.dot(out) >= 0 else (f[0], f[2], f[1]))))
        vv.extend(pv)
    data = bpy.data.meshes.new(name)
    data.from_pydata([tuple(v) for v in vv], [], ff)
    data.update()
    for p in data.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def band_piece(start, end, heights, halfwidth, odd, side):
    profile = PROFILE_ODD if odd else PROFILE_EVEN
    pv, pn, pf = [], [], []
    for i in range(STEPS + 1):
        t = i / STEPS
        angle = start + t * (end - start)
        centre = interp(t, KNOTS, heights)
        width = interp(t, KNOTS, profile) * halfwidth + EDGE
        for j in range(ACROSS + 1):
            s = -1 + 2 * j / ACROSS
            p, n = project(angle, centre + s * width, side)
            pv.append(p)
            pn.append(n)
    row = ACROSS + 1
    for i in range(STEPS):
        for j in range(ACROSS):
            a = i * row + j
            b, c, d = a + 1, a + row + 1, a + row
            pf += [(a, b, c), (a, c, d)]
    return pv, pf, pn


def polygon_piece(points, side):
    # Subdivide each edge so a projected outline hugs the curved skin.
    dense = []
    for (ax, ay), (bx, by) in zip(points, points[1:] + points[:1]):
        for k in range(6):
            f = k / 6
            dense.append((ax + (bx - ax) * f, ay + (by - ay) * f))
    # Grow the outline slightly (about its centroid) to cover the AA edge.
    cx = sum(p[0] for p in dense) / len(dense)
    cy = sum(p[1] for p in dense) / len(dense)
    grown = []
    for x, y in dense:
        dx, dy = x - cx, y - cy
        L = math.hypot(dx, dy) or 1
        grown.append((x + dx / L * EDGE, y + dy / L * EDGE))
    tri = tessellate_polygon([[Vector((x, y, 0)) for x, y in grown]])
    pv, pn = [], []
    for a, z in grown:
        p, n = project(a, z, side)
        pv.append(p)
        pn.append(n)
    return pv, [tuple(t) for t in tri], pn


made = []
for index, (tone, start, end, heights, halfwidth) in enumerate(BANDS):
    pieces = [band_piece(start, end, heights, halfwidth, index % 2 == 1, s) for s in (1, -1)]
    if tone == 'Orange':
        pieces += [polygon_piece(OUTER, 1), polygon_piece(OUTER, -1), polygon_piece(INNER, -1)]
    if tone == 'Gold':
        pieces += [polygon_piece(INNER, 1)]
    made.append((index, tone, build('Stripe_%d_%s' % (index, tone), pieces)))

rows = []
for index, tone, ob in made:
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in ws), min(v.y for v in ws), min(v.z for v in ws)))
    hi = Vector((max(v.x for v in ws), max(v.y for v in ws), max(v.z for v in ws)))
    c, s = (lo + hi) / 2, hi - lo
    # Blender (x, y, z) -> Roblox (x, z + GROUND, -y); checked on Body/BeardFur.
    rows.append({'part': ob.name, 'band': index, 'tone': tone, 'rgb': RGB[tone],
                 'offset': [round(c.x, 4), round(c.z + GROUND, 4), round(-c.y, 4)],
                 'size': [round(s.x, 4), round(s.z, 4), round(s.y, 4)],
                 'triangles': len(ob.data.polygons)})
(OUT / 'bands.json').write_text(json.dumps(rows, indent=1))
print('BANDS', json.dumps([(r['part'], r['triangles']) for r in rows]))

# Export only the ribbons, with the package's own axis settings.
bpy.ops.object.select_all(action='DESELECT')
for _, _, ob in made:
    ob.select_set(True)
bpy.context.view_layer.objects.active = made[0][2]
bpy.ops.export_scene.fbx(filepath=str(OUT / 'rainbowtiger-stripe-bands.fbx'), use_selection=True,
                         object_types={'MESH'}, axis_forward='-Z', axis_up='Y', use_triangles=True,
                         add_leaf_bones=False, path_mode='COPY', embed_textures=False)

# Preview: each band emissive in a DIFFERENT colour from its painted one, so a
# ribbon that misses its stripe shows as two colours side by side.
for index, tone, ob in made:
    m = bpy.data.materials.new('Band_' + tone)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    r, g, b = [c / 255 for c in RGB[BANDS[(index + 3) % 7][0]]]
    bsdf.inputs['Base Color'].default_value = (r, g, b, 1)
    bsdf.inputs['Emission Color'].default_value = (r, g, b, 1)
    bsdf.inputs['Emission Strength'].default_value = 1.5
    ob.data.materials.append(m)
scene = bpy.context.scene
scene.render.filepath = str(OUT / 'preview.png')
scene.render.resolution_x = scene.render.resolution_y = 900
if '--render' in sys.argv:
    bpy.ops.render.render(write_still=True)
print('STRIPE_BANDS_READY', OUT)
