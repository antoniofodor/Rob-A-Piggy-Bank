"""Render the delivered Roblox geometry, save Blender source and per-module FBX.

blender -b -t 3 --python-exit-code 1 --python render_kit.py [-- --draft]
No generated-image postprocessing. Review scene is read from the actual RBXMX.
"""
import argparse
import json
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_kit as kit

parser = argparse.ArgumentParser()
parser.add_argument("--draft", action="store_true")
parser.add_argument("--original", action="store_true")
options = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
spec = json.loads((OUT/"geometry.json").read_text())
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.name = "Assembled Review"
review = bpy.context.scene
CONVERT = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
materials = {}
for name, rgb in spec["palette"].items():
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    c = [v/255 for v in rgb]
    c = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in c]
    mat.diffuse_color = (*c, 1)
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*c, 1)
    node.inputs["Roughness"].default_value = .8
    if name in ("amber", "sky"):
        node.inputs["Emission Color"].default_value = (*c, 1)
        node.inputs["Emission Strength"].default_value = .2 if name == "sky" else .7
    materials[name] = mat


def create_part(part, collection):
    size = part["size"]
    if part["transparency"] >= 1:
        return None
    if part["shape"] == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=1, depth=2)
        obj = bpy.context.object
        # Cylinder native axis X. Bake transform before applying the CFrame.
        for v in obj.data.vertices:
            old = v.co.copy()
            v.co = (old.z*size[0]/2, old.y*size[1]/2, -old.x*size[2]/2)
    elif part["shape"] == "Wedge":
        x, y, z = [v/2 for v in size]
        vs = [(-x, -y, -z), (x, -y, -z), (-x, -y, z), (x, -y, z), (-x, y, z), (x, y, z)]
        faces = [(0, 2, 3, 1), (2, 4, 5, 3), (0, 1, 5, 4), (0, 4, 2), (1, 3, 5)]
        mesh = bpy.data.meshes.new(part["name"])
        mesh.from_pydata(vs, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(part["name"], mesh)
        bpy.context.scene.collection.objects.link(obj)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj = bpy.context.object
        for v in obj.data.vertices:
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
    r, p = part["rotation"], part["position"]
    matrix = Matrix(((r[0], r[1], r[2], p[0]), (r[3], r[4], r[5], p[1]),
                     (r[6], r[7], r[8], p[2]), (0, 0, 0, 1)))
    obj.matrix_world = CONVERT @ matrix
    obj.name = part["name"]
    obj.data.materials.append(materials[part["material"]])
    obj["RobloxGroup"] = part["group"]
    obj["CanCollide"] = part["collide"]
    obj.visible_shadow = False  # Matches the native kit's CastShadow=false.
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def collection(name, scene):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c


def configure(scene):
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8 if options.draft else 12
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.resolution_x = 1152 if options.draft else 1440
    scene.render.resolution_y = 720 if options.draft else 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new(scene.name+" World")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.78, .83, .88, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .65
    scene.unit_settings.system = "NONE"


configure(review)
rgb_to_mat = {tuple(rgb): name for name, rgb in spec["palette"].items()}
tree = ET.parse(OUT/("original-comparison.rbxmx" if options.original else "treehouse-interior-review.rbxmx"))
collections = {}
for model in tree.getroot().find("Item").findall("Item"):
    model_name = model.find("Properties/string[@name='Name']").text
    coll = collection(model_name, review)
    collections[model_name] = coll
    for part in model.iter("Item"):
        if part.get("class") not in ("Part", "WedgePart"):
            continue
        p = part.find("Properties")
        name = p.find("string[@name='Name']").text
        cf = p.find("CoordinateFrame[@name='CFrame']")
        color = int(p.find("Color3uint8").text)
        rgb = ((color >> 16) & 255, (color >> 8) & 255, color & 255)
        token = p.find("token[@name='shape']")
        data = {"name": name, "position": [float(cf.find(k).text) for k in "XYZ"],
            "rotation": [float(cf.find(f"R{r}{c}").text) for r in range(3) for c in range(3)],
            "size": [float(p.find("Vector3").find(k).text) for k in "XYZ"],
            "shape": "Wedge" if part.get("class") == "WedgePart" else "Cylinder" if token is not None and token.text == "2" else "Block",
            "material": rgb_to_mat[rgb], "group": model_name,
            "collide": p.find("bool[@name='CanCollide']").text == "true",
            "transparency": float(p.find("float[@name='Transparency']").text)}
        obj = create_part(data, coll)
        if obj and name == "RequirementSign":
            # Preview equivalent of the SurfaceGui already in the RBXMX file.
            text_curve = bpy.data.curves.new("Gate requirement preview", "FONT")
            text_curve.body = "REBIRTH LOCK"
            text_curve.align_x = "CENTER"
            text_curve.align_y = "CENTER"
            text_curve.size = .7
            text_obj = bpy.data.objects.new("Gate requirement preview", text_curve)
            coll.objects.link(text_obj)
            text_obj.matrix_world = obj.matrix_world @ Matrix.Translation((0, 0, .132))
            text_obj.data.materials.append(materials["woodDark"])


def light(name, position, target, energy, size, scene=review):
    d = bpy.data.lights.new(name, "AREA")
    d.energy, d.shape, d.size = energy, "DISK", size
    obj = bpy.data.objects.new(name, d)
    scene.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


for y in (-6, 11, 29, 47, 62):
    light("Preview daylight", (0, y, 18), (0, y, 0), 3600, 15)
light("Entry daylight", (0, -12, 11), (0, 20, 6), 1600, 12)
sun = bpy.data.lights.new("Daylight sun", "SUN")
sun.energy, sun.angle = 1.5, .18
sun_obj = bpy.data.objects.new("Daylight sun", sun)
review.collection.objects.link(sun_obj)
sun_obj.rotation_euler = (math.radians(25), math.radians(-22), math.radians(-35))

cam_data = bpy.data.cameras.new("Review Camera")
cam_data.sensor_fit = "VERTICAL"
cam_data.sensor_height = 32
camera = bpy.data.objects.new("Review Camera", cam_data)
review.collection.objects.link(camera)
review.camera = camera


def render(name, pos, target, lens=20, ortho=None):
    camera.location = pos
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.type = "ORTHO" if ortho else "PERSP"
    cam_data.lens = lens
    if ortho:
        cam_data.ortho_scale = ortho
    review.render.filepath = str(OUT/"preview"/name)
    bpy.ops.render.render(write_still=True)


(OUT/"preview").mkdir(exist_ok=True)
render("original-hall.png" if options.original else "hall.png", (0, -9, 8), (0, 12, 4), 32/(2*math.tan(math.radians(35))))
if options.original:
    sys.exit(0)
render("achievement-alcove.png", (6, -1, 8.5), (-21.7, -7, 8.3), 29)
# Orthographic construction view: temporarily hide roof and one side wall.
hidden = []
for name, coll in collections.items():
    for obj in coll.objects:
        if obj.type != "MESH":
            continue
        center = obj.matrix_world.translation
        if center.z > 14 or (center.x < -17 and name in ("Room_01", "Room_02", "Entrance")) or name == "Entrance":
            obj.hide_render = True
            hidden.append(obj)
render("layout-cutaway.png", (-61, -48, 67), (0, 16, 2), ortho=85)
for obj in hidden:
    obj.hide_render = False
render("pedestal.png", (-7, 1, 6), (-15.5, 7.125, .8), 32)

# A separate editable template scene; preserve each moving door group in exports.
source_scene = bpy.data.scenes.new("Reusable Templates")
source_scene.world = review.world
bpy.context.window.scene = source_scene
stats = {}
(OUT/"exports").mkdir(exist_ok=True)
for name, template in spec["templates"].items():
    coll = collection(name, source_scene)
    objects = []
    for part in template["parts"]:
        obj = create_part(part, coll)
        if obj:
            objects.append(obj)
    groups = {}
    for obj in objects:
        group = obj["RobloxGroup"]
        # Static art merged per material, moving doors retain separate row/half.
        section = group if group.startswith("Panel_") or group == "Lock" else "Static"
        groups.setdefault((section, obj.data.materials[0].name), []).append(obj)
    merged = []
    for (group, material), items in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in items:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = items[0]
        if len(items) > 1:
            bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = name+"__"+group+"__"+material
        merged.append(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in merged:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(OUT/"exports"/(name+".fbx")), use_selection=True,
        object_types={"MESH"}, axis_forward="-Z", axis_up="Y", bake_anim=False,
        add_leaf_bones=False, apply_scale_options="FBX_SCALE_UNITS")
    triangles = 0
    for obj in merged:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    stats[name] = {"materialSplitMeshes": len(merged), "triangles": triangles}
    for mount_name, mount in template["mounts"].items():
        empty = bpy.data.objects.new(mount_name, None)
        coll.objects.link(empty)
        p = mount["position"]
        r = mount["rotation"]
        empty.matrix_world = CONVERT @ Matrix(((r[0], r[1], r[2], p[0]), (r[3], r[4], r[5], p[1]),
                                               (r[6], r[7], r[8], p[2]), (0, 0, 0, 1)))
        empty.empty_display_type = "ARROWS"
        empty.empty_display_size = .6

bpy.context.window.scene = review
camera.location = (0, -9, 8)
camera.rotation_euler = (Vector((0, 12, 4))-camera.location).to_track_quat("-Z", "Y").to_euler()
cam_data.type, cam_data.lens = "PERSP", 32/(2*math.tan(math.radians(35)))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"treehouse-interior.blend"))
(OUT/"mesh-budget.json").write_text(json.dumps(stats, indent=2))
print("KIT_EXPORT_COMPLETE " + json.dumps(stats))
