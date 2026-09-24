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
PALETTE = {
    "plaster": [231, 199, 147], "plasterLight": [245, 219, 172],
    "wood": [166, 110, 62], "woodLight": [190, 137, 79],
    "woodDark": [116, 73, 41], "bark": [98, 65, 37],
    "floor": [185, 134, 82], "floorLight": [195, 146, 91],
    "leaf": [87, 133, 55], "leafLight": [126, 159, 65],
    "leafDark": [55, 101, 47], "green": [111, 146, 64],
    "gold": [235, 177, 57], "goldLight": [255, 212, 105],
    "iron": [65, 57, 38], "amber": [255, 192, 76],
    "sky": [155, 208, 214], "skyLight": [203, 229, 219],
    "rug": [104, 132, 68], "rugEdge": [164, 178, 105],
}
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


def lantern(side, y, z=10.1):
    x = side * 17.45
    group = "Fixtures"
    box("LanternWallPlate", (side*18.15, y, z+.15), (.28, .75, 2.1), "woodDark", group=group)
    box("LanternArm", (side*17.8, y, z+.9), (1.2, .2, .22), "iron", group=group)
    box("AmberGlass", (x, y, z), (.64, .66, 1.12), "amber", group=group)
    for h in (-.67, .67):
        box("LanternCap", (x, y, z+h), (.96, .95, .22), "iron", group=group)
    for dy in (-.4, .4):
        box("LanternUpright", (x-side*.38, y+dy, z), (.12, .12, 1.24), "iron", group=group)


def window(side, y):
    x, z = side*18.39, 8.9
    group = "Windows"
    cylinder("RoundDaylight", (x, y, z), 2.55, .14, "sky", group, "side")
    # Layered forest silhouettes inside the opaque daylight recess preserve the
    # illusion without exposing the off-map room to the actual outdoor void.
    for k, (dy, h, r, mat) in enumerate(((-.9, -.95, .85, "leaf"), (.85, -.8, 1.05, "leafLight"), (0, .1, .86, "leaf"))):
        cylinder("WindowForest", (x-side*(.105+k*.03), y+dy, z+h), r, .04, mat, group, "side")
    box("WindowTreeTrunk", (x-side*.2, y+.1, z-1.55), (.045, .22, .85), "wood", group=group)
    # A shallow window panel reads as daylight; no transparent exterior/void.
    for k in range(12):
        a = k*math.tau/12
        b = (k+1)*math.tau/12
        beam("RoundWindowRim", (x-side*.2, y+2.7*math.cos(a), z+2.7*math.sin(a)),
             (x-side*.2, y+2.7*math.cos(b), z+2.7*math.sin(b)), .36, "woodLight", group=group)
    box("WindowMullionV", (x-side*.32, y, z), (.24, .17, 4.85), "woodDark", group=group)
    box("WindowMullionH", (x-side*.32, y, z), (.24, 4.85, .17), "woodDark", group=group)
    box("WindowSill", (x-side*.38, y, 6.01), (.92, 5.5, .32), "woodLight", group=group)


def truss(y, foliage=True):
    for side in (-1, 1):
        box("TreePost", (side*18, y, 7.9), (1.1, 1.0, 15.8), "woodDark")
        box("PostFoot", (side*18, y, .58), (1.3, 1.28, 1.16), "wood")
        beam("BranchKnee", (side*18, y, 11.6), (side*13.2, y, 16.1), .7)
        beam("BranchRafter", (side*18, y, 15.7), (0, y, 22), .8)
        beam("BranchFork", (side*16.8, y, 14.2), (side*12, y, 14.9), .36)
        if foliage:
            for k in range(3):
                # Folded, faceted canopy leaves: native wedges, kept above the camera.
                x = side*(16.7-2.9*k)
                z = 17.05+k*.85
                box("CanopyLeaf", (x, y-.15, z), (4.1, 3.0, 1.45),
                    ["leafDark", "leaf", "leafLight"][k], rot=rotation(y=side*(15+13*k), z=side*-12),
                    group="Canopy", shape="Wedge")
                box("CanopyLeafFold", (x, y-.15, z+.15), (3.7, 2.7, 1.35),
                    ["leaf", "leafLight", "leaf"][k], rot=rotation(y=side*(15+13*k)+180, z=side*-12),
                    group="Canopy", shape="Wedge")


def shell(length, start=0, room=True):
    center = start+length/2
    # Structural floor is continuous; boards are a thin visual layer sunk into it.
    box("Floor", (0, center, -.42), (38, length, .84), "woodDark", True, group="Collision")
    for i in range(math.ceil(length/2)):
        y = start+i*2+1
        length_i = min(1.96, start+length-(y-1))
        box("Floorboard", (0, y, -.04), (37.98, length_i, .14),
            "floorLight" if i%3 == 0 else "floor", group="FloorFinish")
    for side in (-1, 1):
        box("SideWall", (side*19.3, center, 8), (.6, length, 16), "plaster", True, group="Collision")
        box("Wainscot", (side*18.94, center, 2.45), (.25, length-.1, 4.9), "woodLight")
        box("WainscotRail", (side*18.76, center, 4.95), (.28, length-.1, .26), "woodDark")
        box("Skirting", (side*18.7, center, .4), (.4, length-.1, .75), "woodDark")
        for y in range(int(start)+2, int(start+length), 4):
            box("PanelStile", (side*18.74, y, 2.55), (.24, .16, 4.35), "wood")
        # Two sloping roof planes, meeting at the ridge (no invisible flat roof).
        beam("RoofSlope", (side*19.55, center, 16), (0, center, 22.55), .48,
             "plasterLight", depth=length, group="Roof")
        box("EaveRail", (side*18.8, center, 15.65), (.7, length, .8), "woodDark")
    box("Ridge", (0, center, 22.25), (.7, length, .8), "woodDark", group="Roof")
    if room:
        for y in (start+1, start+16, start+31):
            truss(y)
        for side in (-1, 1):
            for y in (start+6, start+16, start+26):
                window(side, y)
            for y in (start+10.8, start+21.2):
                lantern(side, y)
        box("RunnerBorder", (0, center, .055), (9.1, length-2, .08), "rugEdge", group="FloorFinish")
        box("Runner", (0, center, .101), (8.65, length-2.3, .045), "rug", group="FloorFinish")


def build_templates():
    template("RoomShell", 32)
    shell(32)
    mount("Entry", (0, 0, 0))
    mount("Exit", (0, 32, 0))
    for side_i, side in enumerate((-1, 1)):
        for i, y in enumerate((6, 16, 26), 1):
            mount(f"Slot_{side_i*3+i:02}", (side*13.5, y, .03), side*90)

    template("Pedestal")
    # A freestanding stump, independent of the floor and neighbouring stations.
    cylinder("Foot", (0, 0, .18), 3.05, .36, "woodDark", "Base", collide=True)
    cylinder("Stump", (0, 0, .89), 2.77, 1.1, "wood", "Base", collide=True)
    for k in range(8):
        a = k*math.tau/8
        box("BarkBand", (2.72*math.cos(a), 2.72*math.sin(a), .89), (.12, .32, 1.02),
            "woodDark", rot=rotation(y=math.degrees(a)), group="Base")
    cylinder("TopRim", (0, 0, 1.49), 2.97, .18, "woodLight", "Base")
    cylinder("GreenDisplayTop", (0, 0, 1.63), 2.78, .12, "green", "Base", collide=True)
    # Pedestal front is Roblox -Z / authored +Y. Slot rotations face the aisle.
    box("CollectionPlate", (0, 3.3, .19), (2.8, 1.05, .34), "woodDark", True, group="Collect")
    box("CollectionInset", (0, 3.3, .37), (2.45, .82, .09), "gold", group="Collect")
    cylinder("CoinMedallion", (0, 2.81, .95), .52, .10, "gold", "Collect", "front")
    cylinder("CoinCenter", (0, 2.88, .95), .38, .05, "goldLight", "Collect", "front")
    box("CoinMark", (0, 2.925, .95), (.1, .04, .47), "woodLight", group="Collect")
    mount("Piggy", (0, 0, 1.69))
    mount("CashLabel", (0, 2.98, 1.25))
    mount("Collect", (0, 3.3, .42))

    template("RebirthGate")
    for side in (-1, 1):
        box("JambWall", (side*18.1, 0, 8), (1.8, 1.25, 16), "plaster", True, group="Frame")
        box("DoorJamb", (side*16.75, -.35, 6.8), (.9, 1.15, 13.6), "woodDark", True, group="Frame")
        box("JambFoot", (side*16.75, -.35, .6), (1.25, 1.35, 1.2), "wood", group="Frame")
    box("HeaderWall", (0, .3, 14.85), (38, 1, 2.9), "plaster", True, group="Frame")
    for side in (-1, 1):
        box("Gable", (side*9.5, .3, 19.425), (1, 19, 6.25), "plaster", True,
            rot=rotation(y=-side*90), group="Frame", shape="Wedge")
    box("DeepTimberHeader", (0, -.52, 14.4), (34.5, 1.4, 1.75), "woodDark", group="Frame")
    box("HeaderInlay", (0, -1.255, 14.4), (32.9, .09, .85), "woodLight", group="Frame")
    # Three horizontal sections per half. Open pose stacks above clear headroom.
    for row in range(3):
        z = 2.24+row*4.45
        for side in (-1, 1):
            group = f"Panel_{row+1}_{'L' if side < 0 else 'R'}"
            x = side*8.13
            box("TimberPanel", (x, 0, z), (16.18, .58, 4.39), "wood", group=group)
            for dx in (-7.4, 7.4):
                box("PanelStile", (x+dx, -.34, z), (.27, .16, 3.9), "woodDark", group=group)
            for h in (-1.82, 1.82):
                box("PanelRail", (x, -.34, z+h), (14.5, .16, .26), "woodLight", group=group)
            box("PanelInset", (x, -.302, z), (14.4, .045, 3.24), "woodLight", group=group)
    # Blocking plane is the only colliding moving-door object.
    box("GateBarrier", (0, .15, 6.72), (32.6, .65, 13.44), "wood", True,
        group="Barrier", transparent=1)
    box("LockBackplate", (0, -.7, 6.9), (3.65, .32, 4.65), "woodDark", group="Lock")
    box("LockBody", (0, -.98, 6.3), (1.7, .34, 1.65), "gold", group="Lock")
    for side in (-1, 1):
        box("LockShackle", (side*.56, -.98, 7.42), (.25, .26, 1.0), "goldLight", group="Lock")
    box("LockShackleTop", (0, -.98, 7.94), (1.35, .26, .25), "goldLight", group="Lock")
    cylinder("Keyhole", (0, -1.17, 6.42), .19, .04, "woodDark", "Lock", "front")
    box("KeyholeStem", (0, -1.18, 6.12), (.16, .035, .4), "woodDark", group="Lock")
    box("RequirementSign", (0, -.75, 10.8), (10, .25, 1.25), "plasterLight", group="Lock")
    mount("Entry", (0, 0, 0))
    mount("Exit", (0, 0, 0))

    template("AchievementVestibule", 14)
    shell(14, -14, False)
    truss(-12.5)
    window(1, -7)
    lantern(1, -2.4)
    # Flat empty wall, framed outside its clear 10 x 6 stud future display area.
    box("AchievementBacking", (-18.52, -7, 7.55), (.22, 10.6, 6.5), "plasterLight", group="AchievementAlcove")
    for y in (-12.55, -1.45):
        box("AlcoveStile", (-18.18, y, 7.55), (.68, .45, 7.1), "woodDark", group="AchievementAlcove")
    for z in (4.13, 10.97):
        box("AlcoveRail", (-18.18, -7, z), (.68, 11.55, .4), "woodDark", group="AchievementAlcove")
    box("EmptyDisplayShelf", (-17.78, -7, 3.85), (1.7, 11.55, .36), "woodLight", group="AchievementAlcove")
    for y in (-11.7, -2.3):
        beam("ShelfBracket", (-18.4, y, 2.6), (-17.18, y, 3.61), .27)
    # Real entry opening; teleport / transition is an integration attachment only.
    for side in (-1, 1):
        box("EntryWall", (side*11.8, -14, 8), (14.4, .7, 16), "plaster", True, group="Entry")
        box("EntryDoorJamb", (side*4.4, -13.58, 5.5), (.45, .7, 11), "woodDark", group="Entry")
    box("EntryUpperWall", (0, -14, 13.6), (38, .7, 5.2), "plaster", True, group="Entry")
    for side in (-1, 1):
        box("EntryGable", (side*9.5, -14, 19.375), (.7, 19, 6.35), "plaster", True,
            rot=rotation(y=-side*90), group="Entry", shape="Wedge")
    box("EntryLintel", (0, -13.6, 11.1), (9.3, .8, .65), "woodDark", group="Entry")
    mount("Entry", (0, -14, 0))
    mount("Exit", (0, 0, 0))
    mount("Door_Exit", (0, -13.5, 0), 180)
    mount("Arrival", (0, -10, 0))
    mount("Achievements", (-18.03, -7, 7.55), -90)


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
    kit, kp = item(root, "Model", "TreehouseInteriorKit")
    templates, _ = item(kit, "Folder", "Templates")
    for name in TEMPLATES:
        add_model(templates, name)
    module, props = item(kit, "ModuleScript", "Builder")
    prop(props, "ProtectedString", "Source", (OUT/"Builder.luau").read_text(encoding="utf-8"))
    save_xml(root, "treehouse-interior-kit.rbxmx")

    root = root_xml()
    demo, _ = item(root, "Model", "TreehouseInterior_Review")
    add_model(demo, "AchievementVestibule", "Entrance")
    for room in range(2):
        add_model(demo, "RoomShell", f"Room_{room+1:02}", [0, 0, -32*room])
        add_model(demo, "RebirthGate", f"Gate_{room+1:02}", [0, 0, -32*(room+1)], opened=room == 0)
        for slot in range(6 if room == 0 else 3):
            anchor = TEMPLATES["RoomShell"]["mounts"][f"Slot_{slot+1:02}"]
            pos = anchor["position"][:]
            pos[2] -= 32*room
            add_model(demo, "Pedestal", f"Pedestal_{room*6+slot+1:02}", pos, -90 if slot < 3 else 90)
    save_xml(root, "treehouse-interior-review.rbxmx")
    report = {name: {"parts": len(t["parts"])+1,
                    "collidingParts": sum(p["collide"] for p in t["parts"]),
                    "mounts": list(t["mounts"])} for name, t in TEMPLATES.items()}
    (OUT/"part-budget.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    build_outputs()
