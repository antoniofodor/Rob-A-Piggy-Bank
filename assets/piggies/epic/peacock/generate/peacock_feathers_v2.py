"""Rounded peacock fan and three-stem crown matched to the epic concept."""
import math
from mathutils import Vector


def build(mesh, tube, mat, join, parts, accessories):
    green = mat("feather", (10, 132, 94))
    shaft = mat("feather_shaft", (10, 112, 91))
    gold = mat("eye_gold", (239, 185, 46))
    turquoise = mat("eye_turquoise", (26, 164, 174))
    navy = mat("eye_navy", (20, 43, 94))

    def plume(name, start, direction, width, length, material, depth=.045):
        """Closed softly domed teardrop, with a narrow root and round shoulders."""
        start, d = Vector(start), Vector(direction).normalized()
        across = Vector((d.z, 0, -d.x)).normalized()
        normal = across.cross(d).normalized()
        rings, sides = 18, 12
        verts = [tuple(start)]
        for i in range(1, rings):
            t = i / rings
            radius = math.sin(math.pi * t) ** .72 * (.62 + .64 * t)
            center = start + d * length * t
            for j in range(sides):
                a = j * math.tau / sides
                verts.append(tuple(center + across * (math.cos(a) * width * radius)
                                   + normal * (math.sin(a) * depth * radius)))
        tip = len(verts)
        verts.append(tuple(start + d * length))
        faces = []
        for j in range(sides):
            faces.append((0, 1 + (j + 1) % sides, 1 + j))
        for i in range(rings - 2):
            for j in range(sides):
                a = 1 + i * sides + j
                b = 1 + i * sides + (j + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        last = 1 + (rings - 2) * sides
        for j in range(sides):
            faces.append((last + j, last + (j + 1) % sides, tip))
        return mesh(name, verts, faces, material)

    # A low, spreading tail mounted into the rump. The widest feathers overlap
    # at the roots, so the fan reads as soft plumage rather than exposed spokes.
    root = Vector((0, .88, -.29))
    for i in range(9):
        angle = math.radians(-100 + 25 * i)
        d = Vector((math.sin(angle), .035, math.cos(angle))).normalized()
        length = 1.83 - .19 * abs(i - 4) / 4
        start = root + d * .10 + Vector((0, .012 * abs(i - 4), 0))
        made = [plume("FanBlade", start, d, .31, length, green, .055)]
        center = start + d * (length * .72)
        # Both faces have the eyespot so it reads from behind during play too.
        for side in (-1, 1):
            for name, width, span, offset, color in (
                ("GoldEye", .221, .70, .054, gold),
                ("TurquoiseEye", .152, .51, .078, turquoise),
                ("NavyEye", .091, .31, .098, navy),
            ):
                pos = center - d * (span * .5) + Vector((0, side * offset, 0))
                made.append(plume(name, pos, d, width, span, color, .016))
            made.append(tube("Shaft", [root + Vector((0, side * .045, 0)),
                                       start + d * (length * .49) + Vector((0, side * .06, 0))],
                             .013, shaft))
        join(made, "FanFeather_%02d" % (i + 1))

    crest = []
    # The centre plume is taller, with the outer pair splayed away from it.
    for i, x in enumerate((-.25, 0, .25)):
        top = 1.46 if i == 1 else 1.34
        stem_tip = Vector((x, -.40, top))
        crest.append(tube("CrestStem", [(x * .18, -.36, .91),
                                        (x * .55, -.38, 1.15), stem_tip], .019, shaft))
        d = Vector((x * .6, 0, 1)).normalized()
        start = stem_tip - d * .015
        crest.append(plume("CrestLeaf", start, d, .100, .285, turquoise, .03))
        for side in (-1, 1):
            crest.append(plume("CrestGold", start + d * .023 + Vector((0, side * .029, 0)),
                               d, .076, .238, gold, .012))
            crest.append(plume("CrestEye", start + d * .055 + Vector((0, side * .045, 0)),
                               d, .054, .177, navy, .012))
    join(crest, "Crest")
    return {"construction": "Nine rounded overlapping feathers with double-sided eyespots; three splayed crest stems"}
