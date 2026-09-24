"""Author and export the lasso kit. Blender --background --python this_file.

Optional selection: append -- elite loop snapped-end daze-star rope.
The standard coil blend is the existing source; it is never regenerated here.
"""
from pathlib import Path
import json
import math
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
PALETTE = {
    'tan': (218, 181, 126), 'brown': (91, 51, 30),
    'purple': (123, 66, 221), 'gold': (244, 184, 54),
    'blue': (85, 201, 246), 'yellow': (255, 218, 54),
    'braided': (176, 115, 69), 'braided_grip': (54, 38, 31),
    'golden': (241, 190, 67), 'golden_grip': (111, 55, 30),
}
MATS = {}
LIMITS = {'rope': 6000, 'elite': 8000, 'loop': 1500, 'snapped-end': 800, 'daze-star': 300}
REPORTS = {}

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    MATS.clear()

def mat(key):
    if key in MATS:
        return MATS[key]
    rgb = PALETTE[key]
    lin = [v / 12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in [c/255 for c in rgb]]
    m = bpy.data.materials.new(key)
    m.diffuse_color = (*lin, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*lin, 1)
    shader.inputs['Roughness'].default_value = .75
    m['rgb_srgb'] = rgb
    MATS[key] = m
    return m

def paint(obj, key):
    obj.data.materials.clear()
    obj.data.materials.append(mat(key))
    for p in obj.data.polygons:
        p.material_index = 0

def select(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

def mesh_obj(name, verts, faces, key):
    m = bpy.data.meshes.new(name+'Geometry')
    m.from_pydata(verts, [], faces)
    m.update()
    o = bpy.data.objects.new(name, m)
    bpy.context.collection.objects.link(o)
    paint(o, key)
    return o

def normals(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = False

def apply(obj, modifier):
    select([obj])
    bpy.ops.object.modifier_apply(modifier=modifier.name)

def bevel(obj, amount, segments=2):
    mod = obj.modifiers.new('Soft low-poly edges', 'BEVEL')
    mod.width = amount
    mod.segments = segments
    apply(obj, mod)
    return obj

def tube(name, points, radius, key, sides=8, closed=False, normal=(0,0,1)):
    points = [Vector(p) for p in points]
    verts, faces = [], []
    count = len(points)
    for i, p in enumerate(points):
        prev = points[(i-1)%count] if closed else points[max(0,i-1)]
        nex = points[(i+1)%count] if closed else points[min(count-1,i+1)]
        tangent = (nex-prev).normalized()
        n = Vector(normal)
        n = (n - tangent*n.dot(tangent)).normalized()
        b = tangent.cross(n).normalized()
        rad = radius[i] if isinstance(radius, list) else radius
        for j in range(sides):
            angle = 2*math.pi*j/sides
            verts.append(tuple(p + rad*(n*math.cos(angle)+b*math.sin(angle))))
    for i in range(count if closed else count-1):
        for j in range(sides):
            faces.append((i*sides+j, i*sides+(j+1)%sides,
                          ((i+1)%count)*sides+(j+1)%sides, ((i+1)%count)*sides+j))
    if not closed:
        faces += [tuple(reversed(range(sides))), tuple((count-1)*sides+j for j in range(sides))]
    obj = mesh_obj(name, verts, faces, key)
    normals(obj)
    return obj

def join(name, objs, key):
    select(objs)
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    paint(obj, key)
    return obj

def star(name, center, radius, key):
    x,y,z = center
    verts = []
    # Ten-point outline, extruded with broad planar faces; bevel rounds tips.
    for depth in (-.10*radius, .10*radius):
        for i in range(10):
            a = math.pi/2 + i*math.pi/5
            r = radius if i%2 == 0 else radius*.49
            verts.append((x+r*math.cos(a), y+depth, z+r*math.sin(a)))
    faces = [tuple(reversed(range(10))), tuple(range(10,20))]
    faces += [(i, (i+1)%10, (i+1)%10+10, i+10) for i in range(10)]
    obj = mesh_obj(name, verts, faces, key)
    normals(obj)
    bevel(obj, radius*.045, 2)
    return obj

def radial_disc(name, center, rings, key, sides=12):
    # Profile around the Blender Y axis, for the front-facing bezel and gem.
    x,y,z = center
    verts, faces = [], []
    for offset, radius in rings:
        for i in range(sides):
            a = math.pi/2 + 2*math.pi*i/sides
            verts.append((x+radius*math.cos(a), y+offset, z+radius*math.sin(a)))
    for k in range(len(rings)-1):
        for i in range(sides):
            faces.append((k*sides+i, k*sides+(i+1)%sides,
                          (k+1)*sides+(i+1)%sides, (k+1)*sides+i))
    faces += [tuple(reversed(range(sides))), tuple((len(rings)-1)*sides+i for i in range(sides))]
    obj = mesh_obj(name, verts, faces, key)
    normals(obj)
    return obj

def bounds(objs):
    bpy.context.view_layer.update()
    points = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector([min(p[k] for p in points) for k in range(3)])
    hi = Vector([max(p[k] for p in points) for k in range(3)])
    return lo, hi

def normalize_origins(objs, center):
    for o in objs:
        world = o.matrix_world.copy()
        for v in o.data.vertices:
            v.co = world @ v.co - center
        o.matrix_world = Matrix.Identity(4)
        normals(o)

def roblox(v):
    return [round(float(v[0]),6), round(float(v[2]),6), round(float(-v[1]),6)]

def attachment(point, tangent=None):
    result = {'position_blender': list(point), 'position_roblox': roblox(point)}
    if tangent is not None:
        result['outward_direction_roblox'] = roblox(Vector(tangent).normalized())
    else:
        result['cframe_roblox'] = roblox(point) + [1,0,0,0,1,0,0,0,1]
    return result

def stats(obj):
    obj.data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    result = {'name': obj.name, 'vertices': len(obj.data.vertices),
              'triangles': len(obj.data.loop_triangles),
              'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
              'flat_shaded': all(not p.use_smooth for p in obj.data.polygons),
              'colors_srgb': list(obj.data.materials[0]['rgb_srgb'])}
    assert bm.calc_volume(signed=True) > 0, obj.name
    bm.free()
    assert result['non_manifold_edges'] == 0, result
    assert result['flat_shaded'], result
    assert len(obj.data.materials) == 1, obj.name
    assert all(n.type != 'TEX_IMAGE' for n in obj.data.materials[0].node_tree.nodes)
    return result

def aim(obj, point=(0,0,0)):
    obj.rotation_euler = (Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()

def stage(key, objs):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = True
    scene.view_settings.view_transform = 'Standard'
    scene.world = bpy.data.worlds.new('PreviewWorld')
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (.35,.40,.50,1)
    bg.inputs['Strength'].default_value = .35
    for name, pos, energy, size in [('Key',(-3,-4,5),420,4),('Fill',(4,-2,2),160,3),('Rim',(1,3,4),250,3)]:
        data = bpy.data.lights.new(name, 'AREA')
        data.energy = energy
        data.shape = 'DISK'
        data.size = size
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = pos
        aim(light)
    lo, hi = bounds(objs)
    center = (lo+hi)/2
    pos = (0.6,-7,.5)
    if key == 'loop':
        pos = (3,-4.5,6)
    elif key == 'snapped-end':
        pos = (.6,-5,3)
    elif key == 'daze-star':
        pos = (.7,-6,.5)
    bpy.ops.object.camera_add(location=Vector(pos)+center)
    cam = bpy.context.object
    cam.name = 'PreviewCamera'
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = max(hi-lo)*1.24
    aim(cam, center)
    scene.camera = cam
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                area.spaces.active.shading.color_type = 'MATERIAL'
                area.spaces.active.region_3d.view_perspective = 'CAMERA'
    return cam

def export_fbx(path, objs):
    select(objs)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={'MESH'},
        axis_forward='-Z', axis_up='Y', apply_unit_scale=True, bake_space_transform=True,
        use_mesh_modifiers=True, mesh_smooth_type='FACE', add_leaf_bones=False, bake_anim=False)

def package(key, objs, attachments, notes, pivot, base_name=None):
    out = ROOT/('alternates/elite-sculpted' if key == 'elite' else key)
    out.mkdir(exist_ok=True, parents=True)
    for folder in ('parts','preview'):
        (out/folder).mkdir(exist_ok=True)
    base = base_name or key
    records = [stats(o) for o in objs]
    total = sum(x['triangles'] for x in records)
    assert total <= LIMITS[key], (key,total,LIMITS[key])
    lo,hi = bounds(objs)
    dims = hi-lo
    report = {'asset': key, 'status': 'local Blender source and FBX; not uploaded or integrated',
        'files': {'blend': base+'.blend', 'fbx': base+'.fbx'},
        'parts': records, 'total_triangles': total, 'triangle_budget': LIMITS[key],
        'textures': 0, 'shading': 'flat', 'pivot': pivot,
        'bounds_blender': {'min': list(lo), 'max': list(hi)},
        'dimensions_blender': list(dims), 'dimensions_roblox': [dims.x,dims.z,dims.y],
        'export_axes': {'up':'Y','forward':'-Z'},
        'attachments': attachments, 'notes': notes,
        'units': 'authoring units; preserve assembly scale; scale attachment positions by the same factor',
        'studio_fit': 'not yet tested in hand or around live piggies'}
    export_fbx(out/(base+'.fbx'), objs)
    for obj in objs:
        export_fbx(out/'parts'/(obj.name.lower()+'.fbx'), [obj])
    camera = stage(key, objs)
    select(objs)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/(base+'.blend')))
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    scene = bpy.context.scene
    scene.render.filepath = str(out/'preview'/(base+'-hero.png'))
    bpy.ops.render.render(write_still=True)
    # A second view shows the depth or the opening, which the hero may obscure.
    lo,hi = bounds(objs)
    target = (lo+hi)/2
    pos = (3,-6,1.8)
    if key == 'loop': pos = (0,0,7)
    if key == 'snapped-end': pos = (.3,-7,.2)
    if key == 'daze-star': pos = (0,-7,0)
    camera.location = target + Vector(pos)
    aim(camera,target)
    scene.render.filepath = str(out/'preview'/(base+'-detail.png'))
    bpy.ops.render.render(write_still=True)
    REPORTS[key] = report
    print('ASSET_COMPLETE '+key+' '+str(total), flush=True)
    return camera

def load_coil():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'rope'/'lasso-rope.blend'))
    bpy.context.preferences.filepaths.save_version = 0
    MATS.clear()
    for obj in list(bpy.data.objects):
        if obj.type != 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    rope, grip = bpy.data.objects['Rope'], bpy.data.objects['Grip']
    paint(rope,'tan')
    paint(grip,'brown')
    # Existing source's inner end and outer tail are fixed by its generator.
    top = (bounds([grip])[0]+bounds([grip])[1])/2
    tail_vertices = sorted(rope.data.vertices, key=lambda v:v.co.z)[:10]
    tip = sum((v.co for v in tail_vertices),Vector())/10
    return rope, grip, top, tip

def build_rope():
    rope,grip,top,tip = load_coil()
    cam = package('rope',[rope,grip],
        {'HandGrip':attachment(top),'RopeExit':attachment(tip,(0,0,-1))},
        ['Shared geometry for Rope, Braided and Golden.',
         'Suggested held span 1.9 studs; confirm grip transform on the live R15 character.',
         'Face the narrow edge towards the body when held to limit leg clipping.'],
        'assembled bounds center', 'lasso-rope')
    # Alternate material previews only: no duplicate mesh assets required.
    cam.location = (.65,-7,.5)
    aim(cam)
    for tier,colors in [('braided',('braided','braided_grip')),('golden',('golden','golden_grip'))]:
        paint(rope,colors[0]); paint(grip,colors[1])
        bpy.context.scene.render.filepath = str(ROOT/'rope'/'preview'/f'lasso-{tier}-hero.png')
        bpy.ops.render.render(write_still=True)
    (ROOT/'rope'/'tier-colors.json').write_text(json.dumps({
        'status':'suggested art palette; gameplay Config unchanged',
        'rope':{'Rope':PALETTE['tan'],'Grip':PALETTE['brown']},
        'braided':{'Rope':PALETTE['braided'],'Grip':PALETTE['braided_grip']},
        'golden':{'Rope':PALETTE['golden'],'Grip':PALETTE['golden_grip']},
    },indent=2)+'\n')

def build_elite():
    rope,grip,top,tip = load_coil()
    paint(rope,'purple'); paint(grip,'gold')
    trim = [grip]
    bezel = radial_disc('Bezel',(top.x,-.15,top.z+.025),
        [(.025,.24),(-.02,.29),(-.065,.29),(-.10,.245)],'gold')
    trim.append(bezel)
    gem = radial_disc('Gem',(top.x,-.245,top.z+.025),
        [(0,.245),(-.055,.235),(-.135,.155)],'blue')
    # Charms touch substantial links, and the bottom star clears the short tail.
    for i,(center,path) in enumerate([
        ((-1.35,0,.22),[(-.96,0,.22),(-1.13,0,.22),(-1.25,0,.22)]),
        ((1.38,0,.22),[(1.07,0,.22),(1.18,0,.22),(1.28,0,.22)]),
        ((-.22,0,-1.17),[(-.22,0,-.78),(-.22,0,-.92),(-.22,0,-1.02)]),
    ]):
        trim.append(tube('Link'+str(i),path,.043,'gold',sides=8,normal=(0,-1,0)))
        trim.append(star('Charm'+str(i),center,.245,'gold'))
    trim = join('Trim',trim,'gold')
    objs = [rope,trim,gem]
    lo,hi = bounds(objs)
    center = (lo+hi)/2
    normalize_origins(objs,center)
    package('elite',objs,{'HandGrip':attachment(top-center),
        'RopeExit':attachment(tip-center,(0,0,-1))},
        ['Rigid decorations; no charm rig or texture.',
         'Uses the same coil and grip location as Rope before assembly recentering.',
         'HandGrip compensates for the decorative bounds; scale by rope body, not charm width.'],
        'assembled bounds center','lasso-elite')

def build_loop():
    reset()
    ring = tube('Loop',[(.84*math.cos(i*2*math.pi/48),.84*math.sin(i*2*math.pi/48),0)
                         for i in range(48)],.11,'tan',sides=10,closed=True)
    stub = tube('Stub',[(.84,0,0),(1.02,0,0),(1.30,0,0),(1.33,0,0)],
                [.11,.11,.11,.08],'tan',sides=8)
    # One obvious collar forms the stylized knot around the outgoing stub.
    knot = tube('Knot',[(1.01,.147*math.cos(i*2*math.pi/16),.147*math.sin(i*2*math.pi/16))
                       for i in range(16)],.07,'tan',sides=8,closed=True,normal=(1,0,0))
    obj = join('Loop',[ring,stub,knot],'tan')
    normalize_origins([obj],Vector((0,0,0)))
    package('loop',[obj],{'RopeExit':attachment(Vector((1.33,0,0)),(1,0,0))},
        ['Opening diameter 1.46 authoring units; outer ring diameter 1.90.',
         'For uniform scale use (torso horizontal diameter + 2*clearance)/1.46.',
         'For noncircular bodies size to the larger horizontal extent, or deform the ring centerline while retaining round rope.',
         'Knot and stub are closed overlapping shells joined into the same MeshPart.'],
        'center of circular opening; horizontal in Roblox XZ')

def build_snapped():
    reset()
    # Broad shaft, rounded intact cap, and four visibly separated bent lobes.
    shaft = tube('SnappedEnd',[(-.58,0,0),(-.57,0,0),(-.54,0,0),(.27,0,0),(.36,0,0)],
                 [.045,.073,.085,.085,.067],'tan',sides=10)
    lobes = []
    for i,(end_y,end_z,end_x) in enumerate([(-.17,.06,.66),(-.045,.19,.71),(.17,.045,.63),(.045,-.17,.68)]):
        lobes.append(tube('Fiber'+str(i),[(.25,end_y*.18,end_z*.18),(.39,end_y*.48,end_z*.48),
                      (end_x-.045,end_y,end_z),(end_x-.015,end_y*1.01,end_z*1.01),(end_x,end_y,end_z)],
                     [.045,.044,.033,.025,.011],'tan',sides=8))
    # Fuse the fibres into the shaft so the fragment is one connected closed solid.
    for lobe in lobes:
        mod = shaft.modifiers.new('Fuse fiber','BOOLEAN')
        mod.operation = 'UNION'
        mod.solver = 'EXACT'
        mod.object = lobe
        apply(shaft,mod)
        bpy.data.objects.remove(lobe,do_unlink=True)
    normalize_origins([shaft],Vector((-.11,0,0)))
    package('snapped-end',[shaft],{
        'IntactEnd':attachment(Vector((-.47,0,0)),(-1,0,0)),
        'BreakRoot':attachment(Vector((.44,0,0)),(1,0,0))},
        ['Four fused, blunt broken fibre lobes; one connected mesh.',
         'Main shaft is 0.94 long and 0.17 wide, excluding splayed tips.',
         'Clone twice and reverse one instance for the snap effect.'],
        'midpoint of main shaft; long axis Roblox X')

def build_star():
    reset()
    obj = star('Star',(0,0,0),.5,'yellow')
    # Widen the extruded profile to one fifth of the star width.
    for v in obj.data.vertices:
        v.co.y *= 2
    normalize_origins([obj],Vector((0,0,0)))
    package('daze-star',[obj],{},
        ['Instance 3-5 copies in code. Orbit, tilt, and fade are runtime effects.',
         'No physical orbit ring, particles or baked glow.'],
        'radial center of star; point up +Y; broad faces +/-Z')

builders = {'rope':build_rope,'elite':build_elite,'loop':build_loop,
            'snapped-end':build_snapped,'daze-star':build_star}
if __name__ == '__main__':
    chosen = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['rope','loop','snapped-end','daze-star']
    for key in chosen:
        builders[key]()
    print('BUILD_COMPLETE '+','.join(chosen),flush=True)
