"""Turn the Studio import of a house into the runtime template the game stands.

    python assets/houses/tools/build_house_runtime.py treehouse 2
    python assets/houses/tools/build_house_runtime.py slime 2

ONE GENERATOR FOR EVERY HOUSE, because a trophy room is a bare shell plus
mounts and the code draws every station from the mount names -- so a template's
whole job is geometry, colliders and coordinates, and none of that is
house-specific. This was `build_treehouse_runtime.py`, hardcoded to one slug;
generalising it is what makes house number three cost nothing.

The FBX import lands in the place file 1,563 studs tall, in whatever spot the
importer chose, with no colours: Studio brought 68 meshes in at default grey.
This writes the same 68 meshes out as a template that is already the right
size, already seated with its feet on y=0 and its front toward +Z (the
street), and already painted from the export's own manifest.

Same shape as blender/guards/build_runtime_assets.py: a recorded Studio import
plus a build step, so the template in the repo is reproducible rather than
something somebody dragged around a place file once.

    python assets/houses/tools/build_treehouse_runtime.py

Writes src/ReplicatedStorage/Shared/HouseTemplates/treehouse.rbxmx, which Rojo
syncs into ReplicatedStorage.Shared -- readable by the server that stands it on
a plot AND by the client that renders it on a shop card, which is why it is not
in ServerStorage.
"""
import json
import math
import sys
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
from xml.etree.ElementTree import Element, SubElement, indent, tostring

ROOT = Path(__file__).resolve().parents[3]
SLUG, REVISION = (sys.argv[1], sys.argv[2]) if len(sys.argv) > 2 else ('treehouse', '2')
ASSET = ROOT / 'assets/houses' / f'{house_slug(SLUG)}-v{REVISION}'

# ONE BLENDER UNIT IS ONE STUD, WHICH IS THE AUTHOR'S OWN SCALE RATHER THAN A
# NUMBER CHOSEN HERE.
#
# The first build scaled to the 30 studs `Config.HOUSE_TIERS` promised and it
# came out visibly small. Measured against the Blender bounds in
# geometry-report.json, the FBX import is EXACTLY 40.3x that size on all three
# axes -- so the source is authored in studs and the importer's factor is the
# only thing in the way. At 1:1 the treehouse is 39.9 studs tall with a cabin
# interior 10.5 studs high and a doorway 8.7 studs tall, which is what "you can
# walk in" needs: a character is about 5 studs. Nothing here is a taste dial.
#
# Derived rather than pinned, so a re-export at a different importer scale
# still lands at the size it was drawn at.

# A HOUSE IS SEEN FROM THE STREET, WHICH IS PLOT-LOCAL +Z. The Blender source
# puts the structural front wall at y=0 with the house at +y, and the
# FBX conversion sends that to -Z -- so the import faces AWAY from the road,
# with its front stairs at z -700. Half a turn puts the stairs at the front.
YAW_HALF_TURN = True


# HOW BIG EACH HOUSE STANDS, ON TOP OF ITS AUTHORED SIZE.
#
# The authored sizes do not ladder with the price at all: measured, ELEVEN of
# the eighteen models are smaller than a tier below them, and the 750K Treehouse
# (55.7 x 54.9 x 39.9) is bigger than everything up to the 80M Sky Castle. So
# the ladder is carried here, and this is a DISPLAY scale applied after the
# importer's own factor -- the mesh ids are untouched, so nothing is re-exported
# and nothing is re-uploaded.
#
# CAPPED BY THE PLOT, WHICH IS WHAT LIMITS THE WHOLE LADDER. The fence interior
# is 67.2 studs and `HOUSE_FRONT_LINE` leaves 57 of depth, so nothing may exceed
# about 62 x 54 -- and the Treehouse already uses it. That is why the numbers
# above it are small: there is nowhere left to grow except UP, which is the axis
# CLAUDE.md says the top tiers sell anyway.
#
# THE BOTTOM THREE ARE DELIBERATELY UNCHANGED, at the designer's choice: the
# complaint was about the tiers ABOVE basic, and a free Cardboard Fort that
# fills a plot leaves the ladder nothing to climb from.
#
# THE TWO WALK-IN HOUSES ARE HELD AT 1.0 AND MUST STAY THERE WHILE INTERIORS ARE
# BEING DRAWN. A scale multiplies the ROOMS and the DOORWAYS while a character
# stays five studs, so the treehouse's 10.5-stud cabin and 8.7-stud doorway are
# a contract with the rig rather than a look. An interior authored against
# today's size is wrong the moment its house is scaled -- so the number for a
# house that is getting an interior has to be settled BEFORE the interior is
# drawn, and these two already have theirs.
# EMPTY AGAIN, BECAUSE THE RESIZE MOVED TO THE SOURCE -- AND LEAVING IT FILLED
# WOULD HAVE SCALED EVERY HOUSE TWICE.
#
# The table above was the ladder applied at runtime to v1 exteriors. The v2
# re-export bakes those same numbers into the .blend: measured, crystal v2 is
# authored at 37.0 x 38.2 x 69.8 and goldenpig v2 at 62.1 x 45.5 x 55.9, which
# are this generator's own scaled outputs to the decimal. So the multiplier is
# already in the geometry, and a row left here would apply it a second time --
# 1.55x on a house that is already 1.55x.
#
# IT HAS TO STAY EMPTY NOW THAT EVERY HOUSE IS WALK-IN. The v2 set ships 14 to
# 31 collision boxes each, so these are rooms rather than closed shells, and a
# scale multiplies a doorway while the character stays five studs. A house that
# wants to be bigger is bigger IN BLENDER, where the interior is drawn against
# the same numbers.
SCALE: dict = {}

# PARTS THE AUTHORED GEOMETRY LEFT FLOATING, moved in FINAL TEMPLATE STUDS,
# after the scale and the half turn. In that frame the front faces +Z (the
# street) and the goldenpig's tail is at -Z, so "towards the body" is +Z.
# Keyed by slug, then by mesh-name prefix so every
# material split of one Blender object moves together.
#
# goldenpig: the tail curl was authored with its stem base at Blender z 32 and
# y 41.4, where the rump is only at z 27.8 -- measured by ray-casting the
# PigBody mesh in golden-piggy-visual.obj -- so the whole tail hung 4.2 studs
# behind the pig. 5.8 forward sinks the stem 1.6 into the rump and leaves the
# curl (its lowest point at y 43.6, where the body reaches z 24.8) clear of it.
#
# modern (Fishbowl House): all four bubbles were authored OUTSIDE the glass
# dome -- their centres 23.3 to 25.6 studs from the dome's centre against a
# glass radius of about 23.9, so three of them hung in the open air. Each is
# moved the least distance that keeps it 1.2+ studs inside the glass AND off
# the inner pod through the whole +-1 stud bob (a grid search against the
# dome and pod in fishbowl-house-visual.obj), so they float in the water.
PART_NUDGE: dict = {
    'goldenpig': {'TailChimney_': (0.0, 0.0, 5.8)},
    'modern': {
        'HouseFX_Bubble_1_': (2.5, -2.25, -2.0),
        'HouseFX_Bubble_2_': (2.75, -2.75, -1.5),
        'HouseFX_Bubble_3_': (-1.75, -1.75, -0.75),
        'HouseFX_Bubble_4_': (-1.75, -3.0, -0.75),
    },
}


def load():
    imported = json.loads((ASSET / 'studio-import.json').read_text())
    manifest = json.loads((ASSET / 'roblox-import-report.json').read_text())
    geometry = json.loads((ASSET / 'geometry-report.json').read_text())
    colours = {m['name']: m['colorRGB'] for m in manifest['meshes']}
    return imported, colours, geometry


def import_scale(imported, geometry):
    """Studs per Blender unit: the inverse of whatever the FBX importer applied."""
    authored = geometry['boundsBlender']['size']
    lo, hi = imported['bounds']['lo'], imported['bounds']['hi']
    # Blender (x, y, z) maps to Roblox (-x, z, y), so the authored depth is the
    # imported Z and the authored height is the imported Y.
    factors = [
        (hi[0] - lo[0]) / authored[0],
        (hi[1] - lo[1]) / authored[2],
        (hi[2] - lo[2]) / authored[1],
    ]
    if max(factors) - min(factors) > 0.05:
        raise SystemExit(f'the import is not uniformly scaled: {factors}')
    return 1.0 / (sum(factors) / 3)


def colour_for(name, colours):
    # Studio suffixes a duplicated mesh name (`Cabin_Amber.001`); the manifest
    # keys on the material name the mesh was split by, which is the part before
    # that suffix. A miss is a hard failure rather than a grey part: the
    # importer already shipped grey once and it looked deliberate.
    if name in colours:
        return colours[name]
    base = name.split('.')[0]
    if base in colours:
        return colours[base]
    raise SystemExit(f'no colour in the manifest for {name}')


def blender_to_import(imported, geometry, scale):
    """Blender (x, y, z) -> the import's own frame, offset included.

    The mapping is Blender (x, y, z) -> Roblox (-x, z, y) at `1 / scale` units
    per stud. The offset is read off the two bounding boxes: -x flips, so
    Blender's MAX x is the import's MIN x.
    """
    factor = 1.0 / scale
    lo = imported['bounds']['lo']
    bmin = geometry['boundsBlender']['min']
    bmax = geometry['boundsBlender']['max']
    off_x = lo[0] - (-bmax[0]) * factor
    off_y = lo[1] - bmin[2] * factor
    off_z = lo[2] - bmin[1] * factor

    def convert(bx, by, bz):
        return (-bx * factor + off_x, bz * factor + off_y, by * factor + off_z)

    return convert


def prop(parent, typ, name, value):
    e = SubElement(parent, typ, name=name)
    if isinstance(value, dict):
        for k, v in value.items():
            SubElement(e, k).text = str(v)
    else:
        e.text = str(value)
    return e


def main():
    imported, colours, geometry = load()
    manifest = json.loads((ASSET / 'roblox-import-report.json').read_text())
    override_file = ASSET / 'material-overrides.json'
    overrides = json.loads(override_file.read_text()) if override_file.exists() else {}
    settings = {m['name']: overrides.get(m['material'], m.get('roblox', {})) for m in manifest['meshes']}
    lo = imported['bounds']['lo']
    hi = imported['bounds']['hi']
    ground = imported['groundY']

    # The author's scale. The house is then seated off the TREE BASE rather
    # than off the lowest part in the import: the ground rocks and the bottom
    # stair tread are authored slightly sunk, and measuring from those would
    # lift the whole house off the lawn by their own burial depth.
    # TWO SCALES, AND THEY ARE NOT INTERCHANGEABLE. `factor` is the importer's
    # own, and `blender_to_import` inverts it to map the Blender-authored boxes
    # and mounts into the import's frame -- so it has to stay the REAL factor or
    # every collider lands somewhere the geometry is not. `scale` is that times
    # the display multiplier, and it is what every final coordinate and size
    # goes through. Folding the multiplier into both would move the colliders.
    factor = import_scale(imported, geometry)
    # Walk-in revisions bake the approved exterior size into Blender geometry.
    # Applying the old exterior multiplier again would enlarge every doorway,
    # collider and mount a second time.
    display = 1.0 if geometry.get('walkIn') else SCALE.get(SLUG, 1.0)
    scale = factor * display
    centre_x = (lo[0] + hi[0]) / 2
    centre_z = (lo[2] + hi[2]) / 2

    # THE TWO FRAMES ARE NOT THE SAME ORIGIN, ONLY THE SAME SCALE.
    #
    # The meshes are dumped from the Studio import; the collision boxes are
    # authored in Blender. Sizes agree exactly on all three axes, and the
    # POSITIONS do not: the FBX carries an offset (measured: 80 studs in Y and
    # 99.9 in Z). Mixing the two frames put the first build's boxes nowhere
    # near the geometry, so the offset is DERIVED from the two bounds rather
    # than assumed to be zero.
    into_import = blender_to_import(imported, geometry, factor)

    root = Element('roblox', version='4')
    model = SubElement(root, 'Item', {'class': 'Model', 'referent': 'model'})
    prop(SubElement(model, 'Properties'), 'string', 'Name', SLUG)

    turn = -1 if YAW_HALF_TURN else 1
    for i, part in enumerate(imported['parts']):
        px, py, pz = part['position']
        x = (px - centre_x) * scale * turn
        y = (py - ground) * scale
        z = (pz - centre_z) * scale * turn
        for prefix, (dx, dy, dz) in PART_NUDGE.get(SLUG, {}).items():
            if part['name'].startswith(prefix):
                x, y, z = x + dx, y + dy, z + dz
        mesh_size = part['meshSize']
        size = [v * scale for v in mesh_size]
        r, g, b = colour_for(part['name'], colours)

        item = SubElement(model, 'Item', {'class': 'MeshPart', 'referent': f'p{i}'})
        p = SubElement(item, 'Properties')
        prop(p, 'string', 'Name', part['name'])
        prop(p, 'Content', 'MeshId', {'url': part['mesh']})
        prop(p, 'Vector3', 'size', dict(zip(('X', 'Y', 'Z'), size)))
        # `InitialSize` is the mesh's own authored size; Roblox renders the mesh
        # scaled by Size/InitialSize, so this pair IS the scale.
        prop(p, 'Vector3', 'InitialSize', dict(zip(('X', 'Y', 'Z'), mesh_size)))
        # A half turn is a rotation about Y: local +X and +Z both flip.
        rot = (-1, 0, 0, 0, 1, 0, 0, 0, -1) if YAW_HALF_TURN else (1, 0, 0, 0, 1, 0, 0, 0, 1)
        prop(p, 'CoordinateFrame', 'CFrame', dict(zip(
            ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'),
            (x, y, z) + rot)))
        prop(p, 'Color3uint8', 'Color3uint8', (r << 16) + (g << 8) + b)
        surface = settings.get(part['name'], settings.get(part['name'].split('.')[0], {}))
        prop(p, 'float', 'Transparency', surface.get('RobloxTransparency', 0))
        # FLAT COLOUR, which is the whole look of this street: CLAUDE.md records
        # that textured materials are what made the old houses read as generic,
        # and that `Metal` shades a colour rather than showing it.
        prop(p, 'token', 'Material', 272)  # SmoothPlastic (288 is Neon: the first
        # build shipped that by mistake and the whole house glowed)
        # Pure scenery, exactly as every other house is: a status symbol may
        # never block a chase or eat a raycast meant for a piggy.
        for name, value in (('Anchored', 'true'), ('CanCollide', 'false'),
                            ('CanTouch', 'false'), ('CanQuery', 'false'),
                            ('CastShadow', 'false')):
            prop(p, 'bool', name, value)

    # THE COLLISION MODEL: invisible boxes, not the meshes themselves.
    #
    # A house you can walk INTO cannot be collided as its own geometry. A
    # mesh's collision is a convex HULL unless it is decomposed, and the hull
    # of a room's walls is a solid block with the doorway filled in -- so the
    # one thing asked for is the one thing that would not work. Precise
    # decomposition of 31,604 triangles would work and costs far more, on
    # every plot, forever.
    #
    # The Blender source ships the answer in `collisionBoxesDraft`: the deck,
    # three cabin walls, two door jambs and a lintel with the DOORWAY LEFT
    # OPEN, all 26 stair treads, the landing, the bridge planks and the
    # lookout floor -- 47 boxes against 68 meshes.
    #
    # Its README calls them "a starting point, not a tested collision model",
    # which is honest: they are what a live walk-through is checked against.
    for i, box in enumerate(geometry['collisionBoxesDraft']):
        bx, by, bz = box['blenderLocation']
        sx, sy, sz = box['sizeXYZ']
        # Into the import's frame first, then through the SAME origin, scale
        # and half turn the meshes take -- so a box cannot drift from the
        # geometry it is the collision for.
        ix, iy, iz = into_import(bx, by, bz)
        x = (ix - centre_x) * scale * turn
        y = (iy - ground) * scale
        z = (iz - centre_z) * scale * turn
        yaw = -box.get('rotationZ', 0.0) + (math.pi if YAW_HALF_TURN else 0.0)
        cos, sin = math.cos(yaw), math.sin(yaw)

        item = SubElement(model, 'Item', {'class': 'Part', 'referent': f'c{i}'})
        p = SubElement(item, 'Properties')
        # Named for what it is: a probe and the next person both read these.
        prop(p, 'string', 'Name', 'Collide_' + box['name'])
        # ALREADY IN STUDS, so no scale here: `sizeXYZ` is Blender units and
        # one Blender unit IS one stud (see the scale note at the top). The
        # first build multiplied by the IMPORT's factor as well and produced a
        # deck 0.6 studs across -- a house with no floor in it.
        # ALREADY IN STUDS, so no importer factor -- but the DISPLAY scale
        # applies, or a scaled house keeps the collision of the unscaled one.
        prop(p, 'Vector3', 'size', dict(zip(('X', 'Y', 'Z'),
            (sx * display, sz * display, sy * display))))
        prop(p, 'CoordinateFrame', 'CFrame', dict(zip(
            ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'),
            (x, y, z, cos, 0, sin, 0, 1, 0, -sin, 0, cos))))
        prop(p, 'float', 'Transparency', 1)
        prop(p, 'bool', 'Anchored', 'true')
        prop(p, 'bool', 'CanCollide', 'true')
        # CanQuery STAYS OFF, as every house in this game always has: a spatial
        # query is how a gum splat finds a floor and how a thrown gadget finds
        # a wall, and a house has never answered either. Solid to WALK on,
        # invisible to queries -- do not change one without the other.
        prop(p, 'bool', 'CanQuery', 'false')
        prop(p, 'bool', 'CanTouch', 'false')
        prop(p, 'bool', 'CastShadow', 'false')

    # THE DISPLAY MOUNTS: where a trophy stands inside the house.
    #
    # A house in this game is meant to be a TROPHY ROOM, and the Blender source
    # already carries the points for it in `mountsBlender` -- Featured, four
    # shelves, a wall, a record and a legacy plaque. They are authored
    # alongside the geometry, so a shelf mount is on the shelf that was drawn,
    # and adding display space later is a Blender change rather than a number
    # nudged here.
    #
    # `Door_Exit` is emitted with the rest deliberately: it is not a display
    # point, it is where somebody LEAVES, and it is the only one of the nine
    # that a future prompt or teleport would want. Named the same way so the
    # reader can see the whole set.
    #
    # Invisible, non-colliding, non-querying markers: a mount is a coordinate
    # with a name, and nothing about it should be walked into or raycast.
    yaws = geometry.get('mountYawBlender', {})
    for name, at in sorted(geometry['mountsBlender'].items()):
        ix, iy, iz = into_import(*at)
        item = SubElement(model, 'Item', {'class': 'Part', 'referent': f'm{name}'})
        p = SubElement(item, 'Properties')
        prop(p, 'string', 'Name', 'Mount_' + name)
        prop(p, 'Vector3', 'size', dict(zip(('X', 'Y', 'Z'), (0.2, 0.2, 0.2))))
        # THE MOUNT CARRIES ITS OWN FACING, through the SAME formula the
        # collision boxes take -- so a mount cannot drift from the geometry it
        # was authored against. `TrophyRoom` reads this frame directly: the
        # runtime used to derive a facing by aiming each display at the
        # Door_Exit mount, which is correct on the back wall and about 43
        # degrees wrong on a side wall.
        #
        # A yaw of 0 reproduces the frame every mount had before this existed,
        # which is what keeps the other templates' unrotated mounts unchanged.
        yaw = -math.radians(yaws.get(name, 0)) + (math.pi if YAW_HALF_TURN else 0.0)
        cos, sin = math.cos(yaw), math.sin(yaw)
        prop(p, 'CoordinateFrame', 'CFrame', dict(zip(
            ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'),
            ((ix - centre_x) * scale * turn, (iy - ground) * scale,
             (iz - centre_z) * scale * turn,
             cos, 0, sin, 0, 1, 0, -sin, 0, cos))))
        prop(p, 'float', 'Transparency', 1)
        prop(p, 'bool', 'Anchored', 'true')
        prop(p, 'bool', 'CanCollide', 'false')
        prop(p, 'bool', 'CanQuery', 'false')
        prop(p, 'bool', 'CanTouch', 'false')
        prop(p, 'bool', 'CastShadow', 'false')

    # Invisible hinge markers travel with the template's parts. Animated leaves
    # remain non-colliding; the opening is never a gameplay gate.
    for door in geometry.get('walkIn', {}).get('doors', []):
        side = door['name'].rsplit('_', 1)[-1]
        ix, iy, iz = into_import(*door['hingeBlender'])
        item = SubElement(model, 'Item', {'class': 'Part', 'referent': 'hinge'+side})
        p = SubElement(item, 'Properties')
        prop(p, 'string', 'Name', 'HouseDoorHinge_'+side)
        prop(p, 'Vector3', 'size', dict(zip(('X','Y','Z'), (.15,.15,.15))))
        prop(p, 'CoordinateFrame', 'CFrame', dict(zip(
            ('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),
            ((ix-centre_x)*scale*turn,(iy-ground)*scale,(iz-centre_z)*scale*turn,turn,0,0,0,1,0,0,0,turn))))
        prop(p, 'float', 'Transparency', 1)
        for name, value in [('Anchored','true'),('CanCollide','false'),('CanQuery','false'),('CanTouch','false'),('CastShadow','false')]:prop(p,'bool',name,value)
        angle = SubElement(item,'Item',{'class':'NumberValue','referent':'angle'+side})
        ap = SubElement(angle,'Properties');prop(ap,'string','Name','OpenDegrees');prop(ap,'double','Value',-door['openDegrees'])

    out = ROOT / 'src/ReplicatedStorage/Shared/HouseTemplates' / f'{SLUG}.rbxmx'
    out.parent.mkdir(parents=True, exist_ok=True)
    indent(root)
    out.write_text(tostring(root, encoding='unicode'))

    width = (hi[0] - lo[0]) * scale
    depth = (hi[2] - lo[2]) * scale
    height = (hi[1] - ground) * scale
    # THE LOWEST FLOOR-LIKE BOX, not one house's own landmark. This used to
    # look up a box literally called "Main deck", which is the treehouse's and
    # would raise StopIteration on any other house.
    floors = [b for b in geometry['collisionBoxesDraft']
              if 'deck' in b['name'].lower() or 'floor' in b['name'].lower()]
    print(f'{len(imported["parts"])} meshes at scale {scale:.5f} (1 stud per Blender unit)')
    print(f'footprint {width:.1f} x {depth:.1f}, height {height:.1f}, feet on y 0')
    if floors:
        low = min((into_import(*b['blenderLocation'])[1] - ground) * scale for b in floors)
        print(f'{len(geometry["collisionBoxesDraft"])} collision boxes; '
              f'lowest floor {low:.1f} studs up')
    else:
        print(f'{len(geometry["collisionBoxesDraft"])} collision boxes; no floor box named')
    print(f'{len(geometry["mountsBlender"])} display mounts: '
          + ', '.join(sorted(geometry['mountsBlender'])))
    print(f'wrote {out.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
