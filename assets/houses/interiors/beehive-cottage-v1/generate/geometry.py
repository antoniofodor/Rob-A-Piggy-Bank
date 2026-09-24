"""Beehive Cottage: honey bands, a faceted vault and native hexagonal prisms."""
import math

PALETTE = {
    "wood": [178, 122, 48], "woodDark": [112, 73, 30],
    "honey": [220, 169, 77], "honeyLight": [241, 199, 116],
    "honeyDark": [163, 106, 38], "wax": [248, 222, 162],
    "cream": [250, 234, 197], "floor": [220, 192, 140],
    "teal": [64, 135, 127], "tealLight": [90, 158, 144],
    "tealDark": [40, 96, 92], "gold": [232, 173, 52],
    "goldLight": [255, 218, 121], "amber": [255, 211, 125],
}
ARCH = [(-19.55, 14.8), (-16, 18.6), (-9.5, 21.65), (0, 22.55),
        (9.5, 21.65), (16, 18.6), (19.55, 14.8)]


def build_templates(k):
    box, beam, cylinder = k.box, k.beam, k.cylinder
    mount, rot = k.mount, k.rotation

    def hex_prism(name, p, radius, height, mat, group="Shell", normal="up", collide=False):
        """One exact hexagonal prism: centre rectangle plus four right wedges.

        Construct in the local horizontal plane, then rotate the whole prism.
        The native parts and Blender use exactly the same geometry.
        """
        h = radius*math.sqrt(3)/2
        start = len(k.current["parts"])
        box(name+"Center", (0, 0, 0), (radius, 2*h, height), mat, collide, group=group)
        for side in (-1, 1):
            for end in (-1, 1):
                box(name+"Corner", (side*.75*radius, end*h/2, 0), (height, h, radius/2),
                    mat, collide, rot=rot(x=180 if end < 0 else 0, z=-side*90), group=group, shape="Wedge")
        r = rot(z=-90) if normal == "side" else rot(x=90) if normal == "front" else k.IDENTITY[:]
        offset = k.rb(p)
        for part in k.current["parts"][start:]:
            local = part["position"]
            part["position"] = [offset[i]+sum(r[i*3+j]*local[j] for j in range(3)) for i in range(3)]
            part["rotation"] = k.mm(r, part["rotation"])

    def floor_cell(x, y, radius=2.5):
        points = [(x+radius*math.cos(a*math.tau/6), y+radius*math.sin(a*math.tau/6), .047) for a in range(6)]
        for p, q in zip(points, points[1:]+points[:1]):
            beam("HoneycombFloorInlay", p, q, .025, "honeyLight", depth=.13, group="FloorFinish")

    def window(side, y):
        for name, x, r, depth, mat in (
                ("HexWindowOuter", 18.81, 2.8, .16, "honeyDark"),
                ("HexWindowRim", 18.69, 2.57, .12, "honeyLight"),
                ("HexDaylight", 18.58, 2.3, .08, "amber")):
            hex_prism(name, (side*x, y, 9.05), r, depth, mat, "Windows", "side")
        x = side*18.48
        # Three spokes repeat the distinctive exterior window motif.
        for angle in (math.pi/2, math.pi/2+math.tau/3, math.pi/2+2*math.tau/3):
            beam("HexWindowSpoke", (x, y, 9.05),
                 (x, y+math.cos(angle)*2.13, 9.05+math.sin(angle)*2.13), .16, "honeyDark", group="Windows")

    def vault_rib(y):
        for side in (-1, 1):
            box("HivePilaster", (side*18.6, y, 7.3), (.8, .78, 14.6), "honeyDark")
            box("PilasterFace", (side*18.15, y, 7.3), (.16, .7, 14.3), "honeyLight")
            box("PilasterFoot", (side*18.6, y, .53), (1.12, 1.06, 1.06), "honey")
        for (x1, z1), (x2, z2) in zip(ARCH, ARCH[1:]):
            beam("VaultHoneyRib", (x1*.968, y, z1-.28), (x2*.968, y, z2-.28), .5, "honeyDark", depth=.7)

    def pendant(y):
        box("PendantStem", (0, y, 20.7), (.14, .14, 2.6), "honeyDark", group="Fixtures")
        hex_prism("CombLanternRim", (0, y, 18.72), .82, .27, "honeyDark", "Fixtures", "front")
        for sign in (-1, 1):
            hex_prism("CombLanternGlow", (0, y+sign*.18, 18.72), .64, .06, "amber", "Fixtures", "front")

    def shell(length, start=0, room=True):
        center = start+length/2
        box("Floor", (0, center, -.42), (38, length, .84), "floor", True, group="Collision")
        box("WaxFloorFinish", (0, center, -.035), (37.98, length-.02, .13), "floor", group="FloorFinish")
        for side in (-1, 1):
            box("SideWall", (side*19.3, center, 7.4), (.6, length, 14.8), "wax", True, group="Collision")
            for height, thick, color in ((.55, 1.1, "honeyDark"), (3.15, .32, "honey"),
                                         (5.45, .38, "honeyDark"), (13.15, .35, "honey"), (14.48, .42, "honeyDark")):
                box("HorizontalHiveBand", (side*18.82, center, height), (.43, length-.06, thick), color)
            box("HoneyLowerWall", (side*18.96, center, 2.9), (.07, length-.05, 4.45), "honeyLight")
        for (x1, z1), (x2, z2) in zip(ARCH, ARCH[1:]):
            beam("WaxVaultFacet", (x1, center, z1), (x2, center, z2), .48, "cream", depth=length, group="Roof")
        for y in ((start+1, start+16, start+31) if room else (start+1.5,)):
            vault_rib(y)
        if room:
            for side in (-1, 1):
                for y in (start+6, start+16, start+26):
                    window(side, y)
                for y, length_drop in ((start+10.5, .85), (start+21.5, 1.2)):
                    box("HoneyDrip", (side*18.5, y, 14.38-length_drop/2), (.18, .38, length_drop), "honey", group="HoneyDetails")
                    cylinder("HoneyDripRoundEnd", (side*18.5, y, 14.38-length_drop), .19, .18,
                             "honey", "HoneyDetails", "side")
            for y in (start+6, start+16, start+26):
                floor_cell(0, y, 2.6)
            for y in (start+9, start+25):
                pendant(y)

    def arch_fill(y, group):
        # Fill to the exact vault profile rather than adding a gabled end wall.
        for (x1, z1), (x2, z2) in zip(ARCH, ARCH[1:]):
            width = x2-x1
            low, high = min(z1, z2), max(z1, z2)
            if low > 14.8:
                box("ArchFillBase", ((x1+x2)/2, y, (low+14.8)/2), (width, 1, low-14.8), "wax", True, group=group)
            box("ArchFillSlope", ((x1+x2)/2, y, (high+low)/2), (1, width, high-low), "wax", True,
                rot=rot(y=90 if z2 > z1 else -90), group=group, shape="Wedge")

    k.template("RoomShell", 32)
    shell(32)
    mount("Entry", (0, 0, 0))
    mount("Exit", (0, 32, 0))
    for side_i, side in enumerate((-1, 1)):
        for i, y in enumerate((6, 16, 26), 1):
            mount(f"Slot_{side_i*3+i:02}", (side*13.5, y, .03), side*90)

    k.template("Pedestal")
    hex_prism("HexFoot", (0, 0, .14), 3.05, .28, "honeyDark", "Base", collide=True)
    hex_prism("HoneycombBody", (0, 0, .84), 2.79, 1.12, "honey", "Base", collide=True)
    hex_prism("GoldTopRim", (0, 0, 1.48), 2.98, .16, "gold", "Base")
    hex_prism("WaxDisplayTop", (0, 0, 1.62), 2.75, .12, "cream", "Base", collide=True)
    box("CollectionPlate", (0, 3.05, .19), (2.8, 1.05, .34), "tealDark", True, group="Collect")
    box("CollectionInset", (0, 3.05, .37), (2.45, .82, .09), "tealLight", group="Collect")
    cylinder("CoinMedallion", (0, 2.47, .9), .48, .09, "gold", "Collect", "front")
    cylinder("CoinCenter", (0, 2.54, .9), .35, .045, "goldLight", "Collect", "front")
    box("CoinMark", (0, 2.576, .9), (.095, .025, .4), "honeyDark", group="Collect")
    mount("Piggy", (0, 0, 1.69))
    mount("CashLabel", (0, 2.65, 1.28))
    mount("Collect", (0, 3.05, .42))

    k.template("RebirthGate")
    for side in (-1, 1):
        box("JambWall", (side*18.1, 0, 7.4), (1.8, 1.25, 14.8), "wax", True, group="Frame")
        box("DoorJamb", (side*16.75, -.35, 6.8), (.9, 1.15, 13.6), "honeyDark", True, group="Frame")
        box("GoldenJambFace", (side*16.75, -.972, 6.8), (.48, .065, 13.4), "honeyLight", group="Frame")
    box("HeaderWall", (0, .3, 14.1), (38, 1, 1.4), "wax", True, group="Frame")
    arch_fill(.3, "Frame")
    box("HoneyGateHeader", (0, -.52, 14.4), (34.5, 1.4, 1.75), "honeyDark", group="Frame")
    box("HeaderInlay", (0, -1.255, 14.4), (33.3, .08, .94), "honeyLight", group="Frame")
    for row in range(3):
        z = 2.24+row*4.45
        for side in (-1, 1):
            group = f"Panel_{row+1}_{'L' if side < 0 else 'R'}"
            x = side*8.13
            box("HivePanel", (x, 0, z), (16.18, .58, 4.39), "tealDark", group=group)
            box("TealPanelInset", (x, -.311, z), (15.55, .04, 3.74), "teal", group=group)
            for height in (-1.92, 1.92):
                box("PanelHoneyRail", (x, -.365, z+height), (15.65, .05, .12), "honeyLight", group=group)
            if row == 1:
                hex_prism("DoorHoneycomb", (x, -.44, z), 1.35, .09, "gold", group, "front")
                hex_prism("DoorHoneycombInset", (x, -.515, z), 1.06, .045, "tealLight", group, "front")
    box("GateBarrier", (0, .15, 6.72), (32.6, .65, 13.44), "teal", True, group="Barrier", transparent=1)
    hex_prism("LockHexFrame", (0, -.7, 6.9), 2.35, .22, "honeyDark", "Lock", "front")
    hex_prism("LockHexBacking", (0, -.87, 6.9), 2.06, .1, "honeyLight", "Lock", "front")
    box("LockBody", (0, -1.07, 6.3), (1.7, .25, 1.65), "gold", group="Lock")
    for side in (-1, 1):
        box("LockShackle", (side*.56, -1.06, 7.42), (.25, .22, 1), "goldLight", group="Lock")
    box("LockShackleTop", (0, -1.06, 7.94), (1.35, .22, .25), "goldLight", group="Lock")
    cylinder("Keyhole", (0, -1.225, 6.42), .19, .04, "woodDark", "Lock", "front")
    box("KeyholeStem", (0, -1.235, 6.12), (.16, .035, .4), "woodDark", group="Lock")
    box("RequirementSign", (0, -.75, 10.8), (10, .25, 1.25), "cream", group="Lock")
    mount("Entry", (0, 0, 0))
    mount("Exit", (0, 0, 0))

    k.template("AchievementVestibule", 14)
    shell(14, -14, False)
    window(1, -7)
    # Reserved rectangular display area remains useful for future UI/trophies.
    box("AchievementBacking", (-18.53, -7, 7.55), (.15, 10.6, 6.5), "cream", group="AchievementAlcove")
    for y in (-12.52, -1.48):
        box("AlcoveGoldStile", (-18.49, y, 7.55), (.34, .34, 7.0), "gold", group="AchievementAlcove")
    for z in (4.2, 10.9):
        box("AlcoveGoldRail", (-18.49, -7, z), (.34, 10.7, .3), "gold", group="AchievementAlcove")
    box("EmptyWaxShelf", (-17.78, -7, 3.85), (1.7, 11.55, .36), "honeyLight", group="AchievementAlcove")
    box("TealShelfEdge", (-16.88, -7, 3.85), (.15, 11.55, .25), "teal", group="AchievementAlcove")
    for y in (-11.5, -2.5):
        hex_prism("AlcoveHoneycomb", (-18.48, y, 11.7), .53, .13, "honey", "AchievementAlcove", "side")
    for side in (-1, 1):
        box("EntryWall", (side*11.8, -14, 7.4), (14.4, .7, 14.8), "wax", True, group="Entry")
        box("EntryDoorJamb", (side*4.4, -13.58, 5.5), (.45, .7, 11), "tealDark", True, group="Entry")
        box("EntryTealFace", (side*4.4, -13.18, 5.5), (.28, .07, 10.9), "teal", group="Entry")
    box("EntryUpperWall", (0, -14, 12.9), (38, .7, 3.8), "wax", True, group="Entry")
    arch_fill(-14, "Entry")
    box("EntryLintel", (0, -13.6, 11.1), (9.3, .8, .65), "tealDark", group="Entry")
    mount("Entry", (0, -14, 0))
    mount("Exit", (0, 0, 0))
    mount("Door_Exit", (0, -13.5, 0), 180)
    mount("Arrival", (0, -10, 0))
    mount("Achievements", (-18.3, -7, 7.55), -90)
