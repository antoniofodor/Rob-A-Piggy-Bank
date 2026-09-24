"""Cardboard Fort art, sharing the six-slot interior connection contract."""
import math

PALETTE = {
    "wood": [174, 130, 86],  # Generic writer's invisible root material.
    "woodDark": [104, 74, 46],  # Also the renderer's label ink.
    "card": [192, 151, 105], "cardLight": [211, 174, 127],
    "cardDark": [153, 111, 71], "paper": [237, 213, 174],
    "tape": [226, 204, 160], "tapeLight": [246, 226, 185],
    "floor": [186, 145, 99], "floorLight": [201, 164, 116],
    "sky": [159, 193, 197], "cloud": [231, 228, 207],
    "stamp": [177, 79, 57], "gold": [226, 173, 66],
    "goldLight": [246, 211, 117],
}


def build_templates(k):
    box, beam, cylinder = k.box, k.beam, k.cylinder
    mount, rot = k.mount, k.rotation

    def rib(y):
        for side in (-1, 1):
            box("FoldedColumn", (side*18.15, y, 8), (1.05, 1.0, 16), "cardDark")
            box("ColumnFace", (side*17.58, y, 8), (.16, .91, 15.8), "cardLight")
            for h in (2.8, 10.6, 15.1):
                box("ColumnTapeBand", (side*18.15, y, h), (1.14, 1.1, .34), "tape")
            beam("FoldedRoofRib", (side*18.6, y, 16.0), (0, y, 22.25), .72, "cardDark", depth=1.0)
            beam("RoofRibFace", (side*18.25, y-.53, 16.02), (0, y-.53, 22.16), .35, "tape", depth=.08)

    def window(side, y):
        x, z = side*18.82, 9.1
        group = "Windows"
        box("SquareDaylight", (x, y, z), (.08, 4.8, 5.2), "sky", group=group)
        for dy in (-2.62, 2.62):
            box("CutWindowEdge", (x-side*.13, y+dy, z), (.35, .37, 5.78), "cardDark", group=group)
        for h in (-2.82, 2.82):
            box("FoldedWindowEdge", (x-side*.16, y, z+h), (.5, 5.56, .37), "paper", group=group)
        box("PaperMullionV", (x-side*.22, y, z), (.2, .13, 5.22), "tapeLight", group=group)
        box("PaperMullionH", (x-side*.22, y, z), (.2, 4.84, .13), "tapeLight", group=group)
        # Tape patches slant only on the wall face, leaving the usable space square.
        for dy, h, angle in ((-2.5, 2.75, -17), (2.5, -2.75, 12)):
            box("WindowCornerTape", (x-side*.42, y+dy, z+h), (.09, .7, 1.28), "tapeLight",
                rot=rot(x=angle), group=group)
        # A small folded awning echoes the exterior cardboard window flaps.
        box("WindowFlap", (x-side*.6, y, z+3.04), (1.1, 5.8, .13), "cardLight",
            rot=rot(z=side*11), group=group)
        for dy in (-2, -1, 0, 1, 2):
            box("CorrugatedFlapEdge", (x-side*1.05, y+dy, z+2.97), (.1, .18, .08), "cardDark", group=group)

    def sun_doodle(side, y, z):
        x = side*18.72
        group = "PaperDetails"
        # The same red sun motif as the existing Cardboard Fort exterior.
        cylinder("SunStampRing", (x, y, z), .73, .05, "stamp", group, "side")
        cylinder("SunStampMiddle", (x-side*.045, y, z), .59, .05, "cardLight", group, "side")
        for i in range(8):
            a = i*math.tau/8
            beam("SunStampRay", (x-side*.08, y+math.cos(a)*.92, z+math.sin(a)*.92),
                 (x-side*.08, y+math.cos(a)*1.25, z+math.sin(a)*1.25), .075, "stamp", depth=.045, group=group)

    def shell(length, start=0, room=True):
        center = start+length/2
        box("Floor", (0, center, -.42), (38, length, .84), "cardDark", True, group="Collision")
        # Broad cardboard panels, with no Treehouse floorboards or carpet.
        rows = math.ceil(length/8)
        panel_length = length/rows
        for i in range(rows):
            y = start+(i+.5)*panel_length
            for x, width in ((-12, 14), (0, 10), (12, 14)):
                box("FloorSheet", (x, y, -.04), (width-.035, panel_length-.035, .14),
                    "floorLight" if x == 0 else "floor", group="FloorFinish")
        for i in range(1, rows):
            box("FloorJoiningTape", (0, start+i*panel_length, .045), (37.94, .24, .025), "tape", group="FloorFinish")
        for side in (-1, 1):
            box("SideWall", (side*19.3, center, 8), (.6, length, 16), "card", True, group="Collision")
            box("FoldedSkirting", (side*18.84, center, .45), (.4, length-.06, .9), "cardDark")
            box("BottomTape", (side*18.61, center, .68), (.08, length-.08, .3), "tape")
            for i in range(rows):
                box("WallSheet", (side*18.96, start+(i+.5)*panel_length, 8.4),
                    (.08, panel_length-.08, 14.6), "cardLight" if i%2 == 0 else "card")
            for i in range(1, rows):
                box("WallJoiningTape", (side*18.88, start+i*panel_length, 8.3), (.06, .48, 14.8), "tape")
            beam("FoldedRoofPlane", (side*19.55, center, 16), (0, center, 22.55), .48,
                 "paper", depth=length, group="Roof")
            box("RoofFoldEdge", (side*18.9, center, 15.82), (.65, length, .45), "cardDark")
        box("RoofRidgeTape", (0, center, 22.15), (.95, length, .11), "tape", group="Roof")
        for y in ((start+1, start+16, start+31) if room else (start+1.5,)):
            rib(y)
        if room:
            for side in (-1, 1):
                for y in (start+6, start+16, start+26):
                    window(side, y)
            sun_doodle(-1, start+21, 7.8)

    k.template("RoomShell", 32)
    shell(32)
    mount("Entry", (0, 0, 0))
    mount("Exit", (0, 32, 0))
    for side_i, side in enumerate((-1, 1)):
        for i, y in enumerate((6, 16, 26), 1):
            mount(f"Slot_{side_i*3+i:02}", (side*13.5, y, .03), side*90)

    k.template("Pedestal")
    box("CartonFoot", (0, 0, .13), (6.0, 6.0, .26), "cardDark", True, group="Base")
    box("CartonBody", (0, 0, .81), (5.6, 5.6, 1.1), "card", True, group="Base")
    box("FoldedTopLip", (0, 0, 1.44), (5.94, 5.94, .16), "cardDark", group="Base")
    for x in (-1.395, 1.395):
        box("TopFlap", (x, 0, 1.59), (2.76, 5.58, .14), "paper", True, group="Base")
    box("TopTape", (-1.65, 0, 1.674), (.56, 5.62, .023), "tapeLight", group="Base")
    for y in (-2.831, 2.831):
        box("FoldedSideTape", (-1.65, y, .81), (.56, .055, 1.1), "tape", group="Base")
    for x in (-2.75, 2.75):
        box("CartonCorner", (x, 2.833, .81), (.12, .06, 1.06), "cardDark", group="Base")
    box("CollectionPlate", (0, 3.3, .19), (2.8, 1.05, .34), "cardDark", True, group="Collect")
    box("CollectionInset", (0, 3.3, .37), (2.45, .82, .09), "gold", group="Collect")
    cylinder("CoinMedallion", (0, 2.89, .89), .48, .09, "gold", "Collect", "front")
    cylinder("CoinCenter", (0, 2.96, .89), .35, .045, "goldLight", "Collect", "front")
    box("CoinMark", (0, 2.996, .89), (.095, .025, .4), "cardDark", group="Collect")
    mount("Piggy", (0, 0, 1.69))
    mount("CashLabel", (0, 3.04, 1.28))
    mount("Collect", (0, 3.3, .42))

    k.template("RebirthGate")
    for side in (-1, 1):
        box("JambWall", (side*18.1, 0, 8), (1.8, 1.25, 16), "card", True, group="Frame")
        box("DoorJamb", (side*16.75, -.35, 6.8), (.9, 1.15, 13.6), "cardDark", True, group="Frame")
        box("JambTape", (side*16.75, -.972, 6.8), (.47, .065, 13.5), "tape", group="Frame")
    box("HeaderWall", (0, .3, 14.85), (38, 1, 2.9), "card", True, group="Frame")
    for side in (-1, 1):
        box("Gable", (side*9.5, .3, 19.425), (1, 19, 6.25), "paper", True,
            rot=rot(y=-side*90), group="Frame", shape="Wedge")
    box("FoldedGateHeader", (0, -.52, 14.4), (34.5, 1.4, 1.75), "cardDark", group="Frame")
    box("HeaderFoldFace", (0, -1.255, 14.4), (34.1, .08, 1.36), "cardLight", group="Frame")
    for x in (-10.5, 10.5):
        box("HeaderTapePatch", (x, -1.315, 14.4), (.9, .035, 1.65), "tapeLight", rot=rot(z=6), group="Frame")
    for row in range(3):
        z = 2.24+row*4.45
        for side in (-1, 1):
            group = f"Panel_{row+1}_{'L' if side < 0 else 'R'}"
            x = side*8.13
            box("CardboardPanel", (x, 0, z), (16.18, .58, 4.39), "card", group=group)
            box("CartonFace", (x, -.307, z), (15.86, .025, 4.04), "cardLight", group=group)
            for dx in (-5.7, 5.7):
                box("PanelJoiningTape", (x+dx, -.345, z), (.65, .04, 4.3), "tape", group=group)
            box("PanelFoldLine", (x, -.34, z-1.93), (15.73, .035, .10), "cardDark", group=group)
    box("GateBarrier", (0, .15, 6.72), (32.6, .65, 13.44), "card", True, group="Barrier", transparent=1)
    box("LockBackplate", (0, -.68, 6.9), (3.65, .25, 4.65), "paper", group="Lock")
    box("LockBody", (0, -.98, 6.3), (1.7, .34, 1.65), "gold", group="Lock")
    for side in (-1, 1):
        box("LockShackle", (side*.56, -.98, 7.42), (.25, .26, 1.0), "goldLight", group="Lock")
    box("LockShackleTop", (0, -.98, 7.94), (1.35, .26, .25), "goldLight", group="Lock")
    cylinder("Keyhole", (0, -1.17, 6.42), .19, .04, "woodDark", "Lock", "front")
    box("KeyholeStem", (0, -1.18, 6.12), (.16, .035, .4), "woodDark", group="Lock")
    box("RequirementSign", (0, -.75, 10.8), (10, .25, 1.25), "paper", group="Lock")
    for x in (-4.3, 4.3):
        box("SignTape", (x, -.91, 10.8), (.45, .03, 1.43), "tapeLight", rot=rot(z=x*2), group="Lock")
    mount("Entry", (0, 0, 0))
    mount("Exit", (0, 0, 0))

    k.template("AchievementVestibule", 14)
    shell(14, -14, False)
    window(1, -7)
    box("AchievementBacking", (-18.72, -7, 7.55), (.15, 10.6, 6.5), "paper", group="AchievementAlcove")
    for y, z, angle in ((-12.2, 10.5, -19), (-1.8, 10.5, 14), (-12.2, 4.6, 12), (-1.8, 4.6, -15)):
        box("AchievementCornerTape", (-18.58, y, z), (.07, .78, 1.4), "tapeLight",
            rot=rot(x=angle), group="AchievementAlcove")
    box("FoldedDisplayShelf", (-17.78, -7, 3.85), (1.7, 11.55, .36), "cardLight", group="AchievementAlcove")
    box("ShelfFrontFold", (-16.9, -7, 3.66), (.16, 11.55, .65), "cardDark", group="AchievementAlcove")
    for y in (-11.5, -2.5):
        box("ShelfTape", (-17.78, y, 4.046), (1.7, .6, .022), "tape", group="AchievementAlcove")
    for side in (-1, 1):
        box("EntryWall", (side*11.8, -14, 8), (14.4, .7, 16), "cardLight", True, group="Entry")
        box("EntryDoorJamb", (side*4.4, -13.58, 5.5), (.45, .7, 11), "cardDark", True, group="Entry")
        box("EntryTape", (side*4.4, -13.18, 5.5), (.29, .07, 10.9), "tape", group="Entry")
    box("EntryUpperWall", (0, -14, 13.6), (38, .7, 5.2), "cardLight", True, group="Entry")
    for side in (-1, 1):
        box("EntryGable", (side*9.5, -14, 19.375), (.7, 19, 6.35), "paper", True,
            rot=rot(y=-side*90), group="Entry", shape="Wedge")
    box("EntryLintel", (0, -13.6, 11.1), (9.3, .8, .65), "cardDark", group="Entry")
    mount("Entry", (0, -14, 0))
    mount("Exit", (0, 0, 0))
    mount("Door_Exit", (0, -13.5, 0), 180)
    mount("Arrival", (0, -10, 0))
    mount("Achievements", (-18.48, -7, 7.55), -90)
