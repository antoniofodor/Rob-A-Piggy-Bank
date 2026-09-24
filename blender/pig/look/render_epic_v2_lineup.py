"""Render the four actual revision meshes together, through Blender MCP."""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/piggies/epic/_concepts-v2"
KEYS = ("hedgehog", "lion", "stormstone", "peacock")
scene = bpy.data.scenes.new("ANIMAL EPICS · v2 lineup")
bpy.context.window.scene = scene
for key, x in zip(KEYS, (-5.7, -1.9, 1.9, 5.7)):
    source = next(s for s in bpy.data.scenes if s.get("skinKey") == key and s.get("revision") == "epic-v2")
    collection = next(c for c in source.collection.children if c.name.startswith(key + "_EPIC_V2"))
    transform = Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(math.radians(-24), 4, "Z")
    for original in collection.objects:
        obj = original.copy(); scene.collection.objects.link(obj)
        obj.matrix_world = transform @ original.matrix_world
    text = bpy.data.curves.new(key + "_label", "FONT")
    text.body = "STORM STONE" if key == "stormstone" else key.upper()
    text.align_x = "CENTER"; text.size = .27
    obj = bpy.data.objects.new(text.name, text); scene.collection.objects.link(obj)
    obj.location = (x, -2, -.98); obj.rotation_euler = (math.radians(65), 0, 0)
    material = bpy.data.materials.new(key + "_label_ink"); material.diffuse_color = (.055, .065, .075, 1)
    obj.data.materials.append(material)

world = bpy.data.worlds.new("EpicLineupWorld"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.64, .69, .72, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = .55
for name, pos, energy, size in [("Key", (-6, -6, 10), 1500, 10), ("Fill", (7, -3, 6), 950, 8), ("Rim", (0, 6, 8), 1800, 10)]:
    data = bpy.data.lights.new(name, "AREA"); data.energy = energy; data.size = size
    obj = bpy.data.objects.new(name, data); scene.collection.objects.link(obj); obj.location = pos
    obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.027))
floor = bpy.context.object
material = bpy.data.materials.new("LineupFloor"); material.diffuse_color = (.67, .68, .64, 1)
floor.data.materials.append(material)
data = bpy.data.cameras.new("LineupCamera"); data.type = "ORTHO"; data.ortho_scale = 15.6
camera = bpy.data.objects.new("LineupCamera", data); scene.collection.objects.link(camera)
camera.location = (0, -20, 8)
camera.rotation_euler = (Vector((0, -.1, .40)) - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = camera
scene.render.engine = "CYCLES"; scene.cycles.samples = 32; scene.cycles.use_denoising = True
scene.view_settings.view_transform = "Standard"; scene.view_settings.look = "None"
scene.render.resolution_x = 2400; scene.render.resolution_y = 850; scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / "epic-v2-blender-lineup.png")
bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(OUT / "epic-v2-lineup.blend"), {scene}, fake_user=True, compress=True)
print(scene.render.filepath)
