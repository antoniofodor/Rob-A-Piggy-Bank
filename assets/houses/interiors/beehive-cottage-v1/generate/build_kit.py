"""Build upload-free Roblox models and a shared geometry spec for Blender.

Run with ordinary Python. All geometry is authored in studs: X across,
Y forward, Z up, then converted to Roblox X, Y up, -Z forward.
"""
from __future__ import annotations

import copy
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

OUT = Path(__file__).resolve().parents[1]
from geometry import PALETTE
import sys
IDENTITY = [1, 0, 0, 0, 1, 0, 0, 0, 1]
TEMPLATES = {}
current = None


def rb(p):
    return [p[0], p[2], -p[1]]


def mm(a, b):
    return [sum(a[r*3+k] * b[k*3+c] for k in range(3))
            for r in range(3) for c in range(3)]


def rotation(x=0, y=0, z=0):
    x, y, z = map(math.radians, (x, y, z))
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    return mm(mm([1, 0, 0, 0, cx, -sx, 0, sx, cx],
                 [cy, 0, sy, 0, 1, 0, -sy, 0, cy]),
              [cz, -sz, 0, sz, cz, 0, 0, 0, 1])


def template(name, length=0):
    global current
    current = {"name": name, "length": length, "parts": [], "mounts": {}}
    TEMPLATES[name] = current


def box(name, p, size, mat="wood", collide=False, rot=None, group="Shell", shape="Block", transparent=0):
    part = {"name": name, "position": rb(p), "size": [size[0], size[2], size[1]],
            "rotation": rot or IDENTITY[:], "material": mat, "collide": collide,
            "group": group, "shape": shape, "transparency": transparent}
    current["parts"].append(part)
    return part


def mount(name, p, yaw=0):
    current["mounts"][name] = {"position": rb(p), "rotation": rotation(y=yaw)}


def beam(name, p, q, width, mat="woodDark", depth=None, group="Shell"):
    p, q = rb(p), rb(q)
    v = [q[i]-p[i] for i in range(3)]
    length = math.sqrt(sum(x*x for x in v))
    up = [x/length for x in v]
    ref = [0, 0, 1] if abs(up[2]) < .95 else [1, 0, 0]
    def cross(a, b):
        return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
    right = cross(up, ref)
    norm = math.sqrt(sum(x*x for x in right))
    right = [x/norm for x in right]
    back = cross(right, up)
    current["parts"].append({"name": name, "position": [(p[i]+q[i])/2 for i in range(3)],
        "size": [width, length, depth or width],
        "rotation": [v for row in zip(right, up, back) for v in row],
        "material": mat, "collide": False, "group": group, "shape": "Block", "transparency": 0})


def cylinder(name, p, radius, height, mat, group="Shell", normal="up", collide=False):
    # Roblox cylinders point along their local X axis.
    rotation_matrix = rotation(z=90) if normal == "up" else (IDENTITY[:] if normal == "side" else rotation(y=90))
    part = box(name, p, (height, radius*2, radius*2), mat, collide, rotation_matrix, group, "Cylinder")
    part["size"] = [height, radius*2, radius*2]
    return part


def build_templates():
    from geometry import build_templates as build_art
    build_art(sys.modules[__name__])


def prop(parent, typ, name, value):
    elem = ET.SubElement(parent, typ, name=name)
    if isinstance(value, dict):
        for key, item in value.items():
            ET.SubElement(elem, key).text = str(item)
    else:
        elem.text = str(value).lower() if isinstance(value, bool) else str(value)
    return elem


counter = 0


def item(parent, cls, name):
    global counter
    counter += 1
    elem = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{counter}"})
    props = ET.SubElement(elem, "Properties")
    prop(props, "string", "Name", name)
    return elem, props


def cframe(parent, name, pos, rot=IDENTITY):
    return prop(parent, "CoordinateFrame", name, dict(zip(
        ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"],
        [round(v, 8) for v in pos+rot])))


def xform(part, offset, yaw):
    result = copy.deepcopy(part)
    r = rotation(y=yaw)
    p = part["position"]
    result["position"] = [offset[i]+sum(r[i*3+j]*p[j] for j in range(3)) for i in range(3)]
    result["rotation"] = mm(r, part["rotation"])
    return result


def add_part(parent, part):
    cls = "WedgePart" if part["shape"] == "Wedge" else "Part"
    elem, props = item(parent, cls, part["name"])
    prop(props, "Vector3", "size", dict(zip("XYZ", part["size"])))
    cframe(props, "CFrame", part["position"], part["rotation"])
    rgb = PALETTE[part["material"]]
    prop(props, "Color3uint8", "Color3uint8", (255 << 24) | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2])
    for key, value in {"Anchored": True, "CanCollide": part["collide"],
                       "CanQuery": part["collide"], "CanTouch": False, "CastShadow": False}.items():
        prop(props, "bool", key, value)
    prop(props, "float", "Transparency", part["transparency"])
    prop(props, "token", "Material", 272)  # SmoothPlastic, including gold and fixtures.
    prop(props, "token", "TopSurface", 0)
    prop(props, "token", "BottomSurface", 0)
    if cls == "Part":
        prop(props, "token", "shape", 2 if part["shape"] == "Cylinder" else 1)
    if part["name"] == "RequirementSign":
        gui, gp = item(elem, "SurfaceGui", "RequirementGui")
        prop(gp, "token", "Face", 2)  # Back (+Z): arrival side of the gate.
        prop(gp, "Vector2", "CanvasSize", {"X": 800, "Y": 100})
        prop(gp, "bool", "AlwaysOnTop", False)
        prop(gp, "float", "LightInfluence", 0)
        label, lp = item(gui, "TextLabel", "Requirement")
        prop(lp, "UDim2", "Size", {"XS": 1, "XO": 0, "YS": 1, "YO": 0})
        prop(lp, "float", "BackgroundTransparency", 1)
        prop(lp, "bool", "TextScaled", True)
        prop(lp, "string", "Text", "REBIRTH LOCK")
        prop(lp, "Color3", "TextColor3", {"R": .2, "G": .13, "B": .08})
        prop(lp, "token", "Font", 20)
    return elem


def add_model(parent, template_name, name=None, offset=None, yaw=0, opened=False):
    offset = offset or [0, 0, 0]
    spec = TEMPLATES[template_name]
    model, mp = item(parent, "Model", name or template_name)
    root_part = {"name": "Root", "position": [0, 0, 0], "size": [.15, .15, .15],
        "rotation": IDENTITY[:], "material": "wood", "collide": False,
        "shape": "Block", "transparency": 1, "group": ""}
    root_elem = add_part(model, xform(root_part, offset, yaw))
    prop(mp, "Ref", "PrimaryPart", root_elem.get("referent"))
    for name, at in spec["mounts"].items():
        attachment, ap = item(root_elem, "Attachment", name)
        cframe(ap, "CFrame", at["position"], at["rotation"])
        prop(ap, "bool", "Visible", False)
    groups = {}
    for source in spec["parts"]:
        group = source["group"]
        if group not in groups:
            groups[group], _ = item(model, "Model" if group.startswith("Panel_") or group == "Lock" else "Folder", group)
        part = copy.deepcopy(source)
        if opened and group.startswith("Panel_"):
            row = int(group.split("_")[1])-1
            part["position"][1] += 16.1-(2.24+row*4.45)
            part["position"][2] -= 1.1+row*.85
        if opened and group in ("Lock", "Barrier"):
            part["transparency"] = 1
            part["collide"] = False
        element = add_part(groups[group], xform(part, offset, yaw))
        if opened and part["name"] == "RequirementSign":
            gui_props = element.find("Item/Properties")
            prop(gui_props, "bool", "Enabled", False)
    return model


def root_xml():
    root = ET.Element("roblox", version="4")
    ET.SubElement(root, "External").text = "null"
    ET.SubElement(root, "External").text = "nil"
    return root


def save_xml(root, name):
    ET.indent(root)
    ET.ElementTree(root).write(OUT/name, encoding="utf-8", xml_declaration=True)


def build_outputs():
    OUT.mkdir(parents=True, exist_ok=True)
    build_templates()
    spec = {"palette": PALETTE, "templates": TEMPLATES,
        "units": "studs", "forward": "-Z", "roomLength": 32,
        "clearWidth": 38, "centerLane": 16, "doorClearWidth": 32.6,
        "doorClearHeight": 13.4, "slotsPerRoom": 6,
        "achievementClearSize": [10, 6],
        "status": "standalone asset kit; no live economy/teleport wiring"}
    (OUT/"geometry.json").write_text(json.dumps(spec, indent=2), encoding="utf-8")
    root = root_xml()
    kit, kp = item(root, "Model", "BeehiveCottageInteriorKit")
    templates, _ = item(kit, "Folder", "Templates")
    for name in TEMPLATES:
        add_model(templates, name)
    module, props = item(kit, "ModuleScript", "Builder")
    prop(props, "ProtectedString", "Source", (OUT/"Builder.luau").read_text(encoding="utf-8"))
    save_xml(root, "beehive-cottage-interior-kit.rbxmx")

    root = root_xml()
    demo, _ = item(root, "Model", "BeehiveCottageInterior_Review")
    add_model(demo, "AchievementVestibule", "Entrance")
    for room in range(2):
        add_model(demo, "RoomShell", f"Room_{room+1:02}", [0, 0, -32*room])
        add_model(demo, "RebirthGate", f"Gate_{room+1:02}", [0, 0, -32*(room+1)], opened=room == 0)
        for slot in range(6 if room == 0 else 3):
            anchor = TEMPLATES["RoomShell"]["mounts"][f"Slot_{slot+1:02}"]
            pos = anchor["position"][:]
            pos[2] -= 32*room
            add_model(demo, "Pedestal", f"Pedestal_{room*6+slot+1:02}", pos, -90 if slot < 3 else 90)
    save_xml(root, "beehive-cottage-interior-review.rbxmx")
    report = {name: {"parts": len(t["parts"])+1,
                    "collidingParts": sum(p["collide"] for p in t["parts"]),
                    "mounts": list(t["mounts"])} for name, t in TEMPLATES.items()}
    (OUT/"part-budget.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    build_outputs()
