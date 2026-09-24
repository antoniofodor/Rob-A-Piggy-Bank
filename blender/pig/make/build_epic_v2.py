"""Build the approved animal epic concepts without replacing the current assets.

Run in Blender, or through tools/blender_mcp_call.py. EPIC_KEY selects one skin.
Each revision owns source/*-epic-v2.blend, sheets/*-epic-v2*.png,
preview/*-epic-v2-*.png, and package/epic-v2/. Shared meshes/UVs stay intact.
"""
from pathlib import Path
import hashlib
import json
import math
import os
import random
import struct
import sys
import zlib

import bpy
import bmesh
from mathutils import Vector

TOOLKIT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLKIT))
import paths

KEY = os.environ.get("EPIC_KEY", "lion")
assert KEY in ("hedgehog", "lion", "stormstone", "peacock")
ROOT = Path(paths.PIGGIES) / "epic" / KEY
for room in ("source", "generate", "sheets", "preview", "package/epic-v2"):
    (ROOT / room).mkdir(parents=True, exist_ok=True)
OUT = ROOT / "package/epic-v2"
CORE = ("Body", "Snout", "Ears", "Legs", "Tail", "EyePreview")
SPECS = {
    "hedgehog": {"body": (119, 74, 44), "cream": (244, 222, 174), "accent": (103, 54, 29), "aura": "fireflies"},
    "lion": {"body": (242, 180, 72), "cream": (249, 227, 167), "accent": (172, 73, 28), "aura": "sunburst"},
    "stormstone": {"body": (88, 106, 132), "cream": (174, 194, 210), "accent": (72, 86, 110), "aura": "storm"},
    "peacock": {"body": (16, 139, 131), "cream": (242, 222, 170), "accent": (9, 112, 79), "aura": "prism"},
}
SPEC = SPECS[KEY]
rng = random.Random(20260923)


def linear(rgb):
    return tuple((v / 255 / 12.92 if v / 255 <= .04045 else ((v / 255 + .055) / 1.055) ** 2.4) for v in rgb)


def mat(name, rgb, emission=0):
    m = bpy.data.materials.new(KEY + "_v2_" + name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*linear(rgb), 1)
    p.inputs["Roughness"].default_value = .72
    p.inputs["Specular IOR Level"].default_value = .22
    if emission:
        p.inputs["Emission Color"].default_value = (*linear(rgb), 1)
        p.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = (*linear(rgb), 1)
    m["palette_rgb"] = list(rgb)
    return m


def painted(name, base, cream, mode="body"):
    m = mat(name, base)
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexCoord")
    xyz = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tex.outputs["Object"], xyz.inputs[0])
    def calc(op, a, b):
        node = nt.nodes.new("ShaderNodeMath"); node.operation = op
        if isinstance(a, (float, int)): node.inputs[0].default_value = a
        else: nt.links.new(a, node.inputs[0])
        if isinstance(b, (float, int)): node.inputs[1].default_value = b
        else: nt.links.new(b, node.inputs[1])
        return node.outputs[0]
    if mode in ("peacock_body", "hedgehog_body", "stormstone_body"):
        x = calc("DIVIDE", xyz.outputs["X"], .72)
        # Warp one oval gently at the forehead instead of intersecting it
        # with a second hard mask. The cheek edge stays smooth and the cream
        # ends above the belly, leaving a continuous base-colour underside.
        brow = calc("MULTIPLY", .09, calc("COSINE", calc("MULTIPLY", xyz.outputs["X"], 4.5), 0))
        z = calc("DIVIDE", calc("ADD", calc("SUBTRACT", xyz.outputs["Z"], .10), brow), .57)
        oval = calc("ADD", calc("MULTIPLY", x, x), calc("MULTIPLY", z, z))
        mask = calc("MULTIPLY", calc("LESS_THAN", xyz.outputs["Y"], -.52), calc("LESS_THAN", oval, 1))
    elif mode == "peacock_paws":
        mask = calc("MULTIPLY", calc("GREATER_THAN", xyz.outputs["Z"], -.87), calc("LESS_THAN", xyz.outputs["Z"], -.78))
    elif mode == "lion":
        mask = calc("LESS_THAN", xyz.outputs["Z"], -.54)
    elif mode == "body":
        x = calc("DIVIDE", xyz.outputs["X"], .74)
        z = calc("DIVIDE", calc("ADD", xyz.outputs["Z"], .14), .76)
        oval = calc("ADD", calc("MULTIPLY", x, x), calc("MULTIPLY", z, z))
        face = calc("MULTIPLY", calc("LESS_THAN", xyz.outputs["Y"], -.40), calc("LESS_THAN", oval, 1))
        mask = calc("MAXIMUM", face, calc("LESS_THAN", xyz.outputs["Z"], -.49))
    else:
        mask = calc("LESS_THAN", xyz.outputs["Z"], -.86)
    mix = nt.nodes.new("ShaderNodeMixRGB")
    mix.inputs[1].default_value = (*linear(base), 1)
    mix.inputs[2].default_value = (*linear(cream), 1)
    nt.links.new(mask, mix.inputs[0])
    nt.links.new(mix.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


for previous in list(bpy.data.scenes):
    if previous.get("revision") == "epic-v2" and previous.get("skinKey") == KEY:
        for obj in list(previous.objects):
            if len(obj.users_scene) == 1: bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(previous)
scene = bpy.data.scenes.new(KEY + " · epic v2")
scene["skinKey"] = KEY; scene["revision"] = "epic-v2"
bpy.context.window.scene = scene
asset = bpy.data.collections.new(KEY + "_EPIC_V2")
scene.collection.children.link(asset)
stage = bpy.data.collections.new(KEY + "_REVIEW")
scene.collection.children.link(stage)


def move(obj, collection=asset):
    for col in list(obj.users_collection): col.objects.unlink(obj)
    collection.objects.link(obj)


source = Path(paths.skin_closed_blend("lion"))
with bpy.data.libraries.load(str(source), link=False) as (available, loaded):
    loaded.objects = list(CORE)
parts = dict(zip(CORE, loaded.objects))
assert all(parts.values()), "Closed source is missing required base meshes"
for name, obj in parts.items():
    asset.objects.link(obj)
    obj.name = KEY + "_" + name
    obj.hide_render = False; obj.hide_viewport = False; obj.hide_select = False; obj.hide_set(False)
    obj["sourcePart"] = name
    for mod in list(obj.modifiers): obj.modifiers.remove(mod)
    obj.data = obj.data.copy()
    for poly in obj.data.polygons: poly.use_smooth = True
body = parts["Body"]
def geometry_signature(obj):
    payload = [list(v.co) for v in obj.data.vertices], [list(p.vertices) for p in obj.data.polygons]
    return hashlib.sha256(json.dumps(payload).encode()).hexdigest()


def uv_signature(obj):
    payload = [[list(p.uv) for p in uv.data] for uv in obj.data.uv_layers]
    return hashlib.sha256(json.dumps(payload).encode()).hexdigest()


source_geometry = {name: geometry_signature(o) for name, o in parts.items()}
source_uvs = {name: uv_signature(o) for name, o in parts.items()}


def setmat(obj, material):
    obj.data.materials.clear(); obj.data.materials.append(material)
    for poly in obj.data.polygons: poly.material_index = 0


body_paint_mode = {"peacock": "peacock_body", "hedgehog": "hedgehog_body", "stormstone": "stormstone_body", "lion": "lion"}.get(KEY, "body")
setmat(body, painted("body_paint", SPEC["body"], SPEC["cream"], body_paint_mode))
setmat(parts["Snout"], mat("snout", SPEC["cream"]))
setmat(parts["Legs"], painted("paws", SPEC["body"], SPEC["cream"], "peacock_paws" if KEY == "peacock" else "paws"))
setmat(parts["Tail"], mat("tail", SPEC["body"]))
ears = parts["Ears"]
# The existing ear-inner material assignment is authored geometry.
for i in range(len(ears.data.materials)):
    ears.data.materials[i] = mat("ear_" + str(i), SPEC["body"] if i == 0 else SPEC["cream"])
setmat(parts["EyePreview"], mat("eyes", (26, 30, 39) if KEY == "peacock" else (35, 29, 32)))
if KEY == "peacock":
    eye_shader = parts["EyePreview"].data.materials[0].node_tree.nodes["Principled BSDF"]
    eye_shader.inputs["Roughness"].default_value = .24
    eye_shader.inputs["Specular IOR Level"].default_value = .4

accessories = []


def mesh(name, verts, faces, material, smooth=True):
    data = bpy.data.meshes.new(KEY + "_" + name)
    data.from_pydata(verts, [], faces); data.update()
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(data); bm.free()
    obj = bpy.data.objects.new(KEY + "_" + name, data); asset.objects.link(obj)
    data.materials.append(material)
    for p in data.polygons: p.use_smooth = smooth
    accessories.append(obj)
    return obj


def leaf(name, base, direction, width, thickness, material, bend=None, sides=10):
    """A closed sculpted tuft: broad shoulders and a curved tapered tip."""
    base, direction = Vector(base), Vector(direction)
    along = direction.normalized()
    bend = Vector(bend or (0, 0, 0))
    ref = Vector((0, -1, 0))
    if abs(along.dot(ref)) > .92: ref = Vector((1, 0, 0))
    across = along.cross(ref).normalized()
    normal = across.cross(along).normalized()
    profile = [(0, .70), (.16, 1), (.36, .94), (.60, .70), (.82, .34), (.97, .04)]
    verts = []
    for t, radius in profile:
        center = base + direction * t + bend * (t * t)
        for j in range(sides):
            a = j * math.tau / sides
            verts.append(tuple(center + across * (math.cos(a) * width * radius) + normal * (math.sin(a) * thickness * radius)))
    verts.extend([tuple(base - along * .018), tuple(base + direction + bend)])
    faces = []
    for i in range(len(profile) - 1):
        for j in range(sides):
            a = i * sides + j; b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    for j in range(sides):
        faces.append((len(verts) - 2, (j + 1) % sides, j))
        a = (len(profile) - 1) * sides + j
        b = (len(profile) - 1) * sides + (j + 1) % sides
        faces.append((a, b, len(verts) - 1))
    return mesh(name, verts, faces, material)


def hit(direction):
    d = Vector(direction).normalized()
    ok, point, normal, _ = body.ray_cast(d * 4, -d)
    assert ok, tuple(d)
    return point, normal


def tube(name, coords, radius, material):
    verts, faces = [], []
    for i, coord in enumerate(coords):
        p = Vector(coord)
        tangent = Vector(coords[min(i + 1, len(coords) - 1)]) - Vector(coords[max(i - 1, 0)])
        tangent.normalize()
        a = tangent.cross(Vector((0, 1, 0)))
        if a.length < .01: a = tangent.cross(Vector((1, 0, 0)))
        a.normalize(); b = tangent.cross(a)
        for j in range(6): verts.append(tuple(p + radius * (a * math.cos(j * math.tau / 6) + b * math.sin(j * math.tau / 6))))
    for i in range(len(coords) - 1):
        for j in range(6):
            a = i * 6 + j; b = i * 6 + (j + 1) % 6
            faces.append((a, b, b + 6, a + 6))
    faces.extend([tuple(reversed(range(6))), tuple(range(len(verts) - 6, len(verts)))])
    return mesh(name, verts, faces, material)


def join(obs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs: o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    o = obs[0]; o.name = KEY + "_" + name
    accessories[:] = [a for a in accessories if a in list(scene.objects)]
    return o


if KEY == "hedgehog":
    colors = [mat("quill_" + str(i), rgb) for i, rgb in enumerate([(80, 43, 25), (100, 55, 30), (116, 65, 37)])]
    for row, (latitude, count) in enumerate([(-12, 18), (7, 19), (26, 18), (45, 15), (63, 11), (79, 6)]):
        lat = math.radians(latitude)
        for j in range(count):
            theta = math.radians(62 + 236 * (j + (row % 2) * .3) / (count - 1))
            d = Vector((math.sin(theta) * math.cos(lat), -math.cos(theta) * math.cos(lat), math.sin(lat)))
            p, n = hit(d)
            tail = Vector((0, 1, 0)); tangent = tail - n * tail.dot(n)
            tangent.normalize()
            direction = (n * .62 + tangent * .80).normalized() * rng.uniform(.39, .48)
            leaf("Quill", p - n * .055, direction, rng.uniform(.16, .20), .09, colors[(j + row) % 3], tangent * .075)
    join(list(accessories), "Quills")

elif KEY == "lion":
    import runpy
    lion_module = runpy.run_path(str(ROOT / "generate/lion_mane_v2.py"))
    mane = lion_module["build"](mesh, hit, mat, join, leaf, parts, accessories)

elif KEY == "stormstone":
    stones = [mat("stone_" + str(i), rgb) for i, rgb in enumerate([(68, 80, 103), (88, 105, 132), (110, 125, 146)])]
    glow = mat("cyan_cracks", (42, 218, 246), 2.2)
    # A contiguous staggered shell of low stone tiles. Narrow cyan borders sit
    # beneath each tile rather than replacing half the rocks with tall bolts.
    for row, (lat_deg, count) in enumerate([(5, 10), (28, 10), (51, 8), (74, 5)]):
        for j in range(count):
            theta = math.radians(57 + 246 * (j + .25 * (row % 2)) / (count - 1))
            lat = math.radians(lat_deg)
            d = Vector((math.sin(theta) * math.cos(lat), -math.cos(theta) * math.cos(lat), math.sin(lat)))
            p, n = hit(d)
            across = Vector((math.cos(theta), math.sin(theta), 0)).normalized()
            along = n.cross(across).normalized()
            width = .22 if row < 3 else .19
            height = .235
            ring = []
            for k in range(6):
                a = math.tau * k / 6 + .1
                q, _ = hit(p + across * math.cos(a) * width + along * math.sin(a) * height)
                ring.append(q)
            verts = [tuple(q + n * .025) for q in ring] + [tuple(q * .0 + p + (q - p) * .80 + n * rng.uniform(.12, .16)) for q in ring]
            verts.append(tuple(p + n * .19))
            faces = [tuple(reversed(range(6)))]
            for k in range(6):
                nxt = (k + 1) % 6
                faces.extend([(k, nxt, nxt + 6, k + 6), (k + 6, nxt + 6, 12)])
            rock = mesh("Plate", verts, faces, stones[(j + row) % 3], False)
            for face in rock.data.polygons:
                if face.index % 4 == 0:
                    if len(rock.data.materials) == 1: rock.data.materials.append(stones[(j + row + 1) % 3])
                    face.material_index = 1
            # Inset outlines remain mostly occluded, leaving thin lit seams.
            outline = [q + n * .008 for q in ring]
            tube("Crack", outline + [outline[0]], .009, glow)
    rocks = [o for o in accessories if "Plate" in o.name]; cracks = [o for o in accessories if "Crack" in o.name]
    join(rocks, "StonePlates"); join(cracks, "GlowSeams")
    bolts = []
    for x, y, z in [(-.48, .24, .96), (.38, .55, .95), (-.12, .87, .71)]:
        bolts.append(tube("Bolt", [(x, y, z), (x - .05, y, z + .10), (x + .07, y, z + .14), (x + .025, y, z + .27)], .012, glow))
    join(bolts, "Lightning")
    eyes = []
    for x in (-.318, .318):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=.063, location=(x, -.975, .376))
        eye = bpy.context.object; move(eye); setmat(eye, glow)
        for poly in eye.data.polygons: poly.use_smooth = True
        accessories.append(eye); eyes.append(eye)
    join(eyes, "GlowEyes")

elif KEY == "peacock":
    import runpy
    peacock_module = runpy.run_path(str(ROOT / "generate/peacock_feathers_v2.py"))
    peacock = peacock_module["build"](mesh, tube, mat, join, parts, accessories)


def palette_atlas():
    """One reusable UV palette per skin means one material per accessory mesh."""
    materials = []
    for o in accessories:
        for m in o.data.materials:
            if m not in materials: materials.append(m)
    colors = [tuple(m.get("palette_rgb", (255, 255, 255))) for m in materials]
    width, height, swatch = max(1, len(colors)) * 16, 16, 16
    row = b"".join(bytes(c) * swatch for c in colors)
    raw = b"".join(b"\0" + row for _ in range(height))
    def chunk(kind, data): return struct.pack("!I", len(data)) + kind + data + struct.pack("!I", zlib.crc32(kind + data) & 0xffffffff)
    file = ROOT / "sheets" / (KEY + "-epic-v2-palette.png")
    file.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
    image = bpy.data.images.load(str(file)); image.pack()
    plain = mat("accessory_palette", (255, 255, 255))
    t = plain.node_tree.nodes.new("ShaderNodeTexImage"); t.image = image; t.interpolation = "Closest"
    plain.node_tree.links.new(t.outputs["Color"], plain.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    for o in accessories:
        # Emitting objects are isolated so Roblox can give these Neon material.
        emitting = all(m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value > 0 for m in o.data.materials)
        uv = o.data.uv_layers.new(name="EpicPalette")
        for poly in o.data.polygons:
            i = materials.index(o.data.materials[poly.material_index])
            for li in poly.loop_indices: uv.data[li].uv = ((i + .5) / len(materials), .5)
        if not emitting: setmat(o, plain)
        o["robloxMaterial"] = "Neon" if emitting else "SmoothPlastic"
    return file


palette = palette_atlas()


def bake_coat():
    scene.render.engine = "CYCLES"; scene.cycles.samples = 1
    scene.render.bake.use_pass_direct = False; scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True; scene.render.bake.margin = 12
    scene.render.bake.use_selected_to_active = False
    for group, names in (("body", ("Body",)), ("trim", ("Snout", "Ears", "Legs", "Tail"))):
        resolution = 2048 if KEY in ("peacock", "hedgehog", "stormstone") else 1024
        image = bpy.data.images.new(KEY + "_epic_v2_" + group, width=resolution, height=resolution, alpha=False)
        image.generated_color = (*linear(SPEC["body"]), 1)
        bpy.ops.object.select_all(action="DESELECT")
        for name in names:
            obj = parts[name]; obj.select_set(True)
            for material in obj.data.materials:
                node = material.node_tree.nodes.new("ShaderNodeTexImage"); node.image = image
                material.node_tree.nodes.active = node
        bpy.context.view_layer.objects.active = parts[names[0]]
        bpy.ops.object.bake(type="DIFFUSE")
        image.filepath_raw = str(ROOT / "sheets" / (KEY + "-epic-v2-" + group + ".png"))
        image.file_format = "PNG"; image.save(); image.pack()
        baked = mat(group + "_baked", SPEC["body"])
        node = baked.node_tree.nodes.new("ShaderNodeTexImage"); node.image = image
        baked.node_tree.links.new(node.outputs["Color"], baked.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
        for name in names: setmat(parts[name], baked)


bake_coat()
scene.render.engine = "CYCLES"; scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.resolution_x = 900; scene.render.resolution_y = 900; scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
world = bpy.data.worlds.new(KEY + "_Studio"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (*linear((190, 202, 211)), 1)
world.node_tree.nodes["Background"].inputs[1].default_value = .55


def light(name, pos, energy, size):
    data = bpy.data.lights.new(KEY + name, "AREA"); data.energy = energy; data.shape = "DISK"; data.size = size
    o = bpy.data.objects.new(data.name, data); stage.objects.link(o); o.location = pos
    o.rotation_euler = (-o.location).to_track_quat("-Z", "Y").to_euler()


light("Key", (-3, -4, 6), 360, 5)
light("Fill", (4, -1, 3), 190, 4)
light("Rim", (1, 4, 5), 420, 3)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.027))
floor = bpy.context.object; floor.name = KEY + "_ReviewFloor"; move(floor, stage)
setmat(floor, mat("floor", (210, 211, 204)))
camera_data = bpy.data.cameras.new(KEY + "_Camera"); camera = bpy.data.objects.new(camera_data.name, camera_data)
stage.objects.link(camera); scene.camera = camera; camera_data.type = "ORTHO"
camera_data.lens = 50


def aim(pos, target, span):
    camera.location = pos; camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = span


hero_position = (-4, -6, 2.6) if KEY == "peacock" else (-4, -6, 3) if KEY == "lion" else (4, -6, 3)
aim(hero_position, (0, 0, .30 if KEY == "peacock" else .12), 4.35 if KEY == "peacock" else 3.35)

# Source scene contains only this pig, its packed images and review stage.
source_out = ROOT / "source" / (KEY + "-epic-v2.blend")
scene["concept"] = "assets/piggies/epic/_concepts-v2/epic-concepts.png"
scene["skinKey"] = KEY; scene["revision"] = "epic-v2"
bpy.data.libraries.write(str(source_out), {scene}, fake_user=True, compress=True)


def bounds(obs):
    pts = [o.matrix_world @ v.co for o in obs for v in o.data.vertices]
    return [[min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]]


all_objects = list(parts.values()) + list(accessories)
report = {"skin": KEY, "revision": "epic-v2", "status": "authored; Roblox import pending", "bodyWidthStuds": 12,
          "sourceScene": str(source_out.relative_to(paths.REPO)), "concept": scene["concept"], "aura": SPEC["aura"],
          "baseGeometryUnchanged": all(source_geometry[n] == geometry_signature(o) for n, o in parts.items()),
          "baseUVsPreserved": all(source_uvs[n] == uv_signature(o) for n, o in parts.items()),
          "sourceHash": hashlib.sha256(source.read_bytes()).hexdigest(),
          "generatorHash": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), "parts": []}
if KEY == "lion":
    report["maneLegIntersectionPairs"] = int(mane["legIntersectionPairs"])
    report["maneConstruction"] = mane["construction"]
    report["maneGeneratorHash"] = hashlib.sha256((ROOT / "generate/lion_mane_v2.py").read_bytes()).hexdigest()
if KEY == "peacock":
    report["featherConstruction"] = peacock["construction"]
    report["featherGeneratorHash"] = hashlib.sha256((ROOT / "generate/peacock_feathers_v2.py").read_bytes()).hexdigest()
for o in all_objects:
    bm = bmesh.new(); bm.from_mesh(o.data)
    boundary = sum(e.is_boundary for e in bm.edges); nonmanifold = sum(not e.is_manifold for e in bm.edges)
    bm.free()
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    assert tris < 20000, (o.name, tris)
    if o in accessories: assert nonmanifold == 0, (o.name, nonmanifold)
    lo, hi = bounds([o])
    report["parts"].append({"name": o.name, "triangles": tris, "boundaryEdges": boundary, "nonManifoldEdges": nonmanifold,
                            "role": "base" if o in parts.values() else "accessory", "material": o.get("robloxMaterial", "SmoothPlastic"),
                            "boundsSource": [lo, hi], "offsetRobloxStuds": [(lo[0]+hi[0])*3, (lo[2]+hi[2])*3+6.62, -(lo[1]+hi[1])*3],
                            "sizeRobloxStuds": [(hi[0]-lo[0])*6, (hi[2]-lo[2])*6, (hi[1]-lo[1])*6]})


def export(obs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs: o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    file = OUT / name
    bpy.ops.export_scene.fbx(filepath=str(file), use_selection=True, object_types={"MESH"}, global_scale=6,
                             apply_unit_scale=False, bake_space_transform=True, axis_forward="-Z", axis_up="Y",
                             use_mesh_modifiers=False, mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False,
                             path_mode="COPY", embed_textures=True)
    # Round-trip the actual FBX, not just the Blender source.
    known = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(file), use_anim=False)
    imported = [o for o in bpy.data.objects if o not in known]
    meshes = [o for o in imported if o.type == "MESH"]
    assert len(meshes) == len(obs), (name, len(meshes), len(obs))
    original = bounds(obs); actual = bounds(meshes)
    error = max(abs(original[j][i] * 6 - actual[j][i]) for j in range(2) for i in range(3))
    assert error < .001, (name, error)
    assert all(o.data.uv_layers for o in meshes), name + " lost UVs"
    for o in imported: bpy.data.objects.remove(o, do_unlink=True)
    return {"file": name, "sha256": hashlib.sha256(file.read_bytes()).hexdigest(), "meshCount": len(obs), "roundTripBoundsError": error}


report["exports"] = [export(all_objects, KEY + "-epic-v2-complete.fbx"), export(accessories, KEY + "-epic-v2-accessories.fbx")]
report["totalTriangles"] = sum(p["triangles"] for p in report["parts"])
(OUT / "asset-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
# Render after exporting so the previews verify precisely the authored set.
views = [("hero", hero_position, (0, 0, .30 if KEY == "peacock" else .12), 4.35 if KEY == "peacock" else 3.35),
         ("front", (0, -7, 1.6), (0, 0, .30 if KEY == "peacock" else .1), 4.35 if KEY == "peacock" else 3.35),
         ("back", (3, 6, 3), (0, .15, .55 if KEY == "peacock" else .25), 4.35 if KEY == "peacock" else 3.5),
         ("crown", (2, -3, 7), (0, .25 if KEY == "peacock" else 0, .2), 4.35 if KEY == "peacock" else 3.5)]
for name, position, target, span in views:
    if os.environ.get("EPIC_VIEWS") and name not in os.environ["EPIC_VIEWS"].split(","):
        continue
    aim(position, target, span)
    scene.render.filepath = str(ROOT / "preview" / (KEY + "-epic-v2-" + name + ".png"))
    bpy.ops.render.render(write_still=True)
aim(views[0][1], views[0][2], views[0][3])
bpy.data.libraries.write(str(source_out), {scene}, fake_user=True, compress=True)
print(json.dumps({"skin": KEY, "source": str(source_out), "triangles": report["totalTriangles"], "exports": report["exports"]}))
