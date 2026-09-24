"""Honey-orange curl, translucent amber droplet, and curved reflective streak."""
import math
import bpy
from mathutils import Vector


def apply(tail):
    # Restore the canonical curl before rebuilding the separate glass drop.
    # It needs its own mesh/material to stay translucent after import.
    if tail.get('honeyDropApplied'):
        import paths
        with bpy.data.libraries.load(paths.skin_closed_blend('giraffe'), link=False) as (_, loaded):
            loaded.objects = ['Tail']
        original = loaded.objects[0]
        tail.data = original.data.copy()
        bpy.data.objects.remove(original, do_unlink=True)
        del tail['honeyDropApplied']
    for name in ('HoneyDrop', 'HoneyDropHighlight'):
        old = bpy.data.objects.get(name)
        if old: bpy.data.objects.remove(old, do_unlink=True)
    rgb = (239, 145, 22)
    material = bpy.data.materials.new('honeycomb_orange_tail')
    material.use_nodes = True
    shader = material.node_tree.nodes['Principled BSDF']
    linear = tuple(v/255/12.92 if v/255 <= .04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Roughness'].default_value = .38
    tail.data.materials.clear(); tail.data.materials.append(material)
    for p in tail.data.polygons: p.material_index = 0

    # Sample the orange colour from an existing tail UV island; the added drop
    # needs no separate texture and doesn't move any other part's UVs.
    poly = max((p for p in tail.data.polygons if .99 < p.center.y < 1.20), key=lambda p:p.area)
    uv = tail.data.uv_layers.active
    sample = sum((uv.data[i].uv for i in poly.loop_indices), Vector((0,0))) / len(poly.loop_indices)
    top = Vector((.13, 1.455, .54))
    rings, sides, height = 20, 24, .36
    verts = [tuple(top)]
    for i in range(1, rings):
        angle = math.pi*i/rings
        z = top.z - height*(1-math.cos(angle))/2
        radius = .175*math.sin(angle)*(.65-.35*math.cos(angle))
        for j in range(sides):
            theta = math.tau*j/sides
            verts.append((top.x + radius*math.cos(theta), top.y + radius*math.sin(theta), z))
    bottom = len(verts); verts.append((top.x,top.y,top.z-height))
    faces=[]
    for j in range(sides): faces.append((0,1+j,1+(j+1)%sides))
    for i in range(rings-2):
        for j in range(sides):
            a=1+i*sides+j; b=1+i*sides+(j+1)%sides
            faces.append((a,a+sides,b+sides,b))
    last=1+(rings-2)*sides
    for j in range(sides): faces.append((last+j,bottom,last+(j+1)%sides))
    data=bpy.data.meshes.new('HoneyDrop'); data.from_pydata(verts,[],faces); data.update()
    drop=bpy.data.objects.new('HoneyDrop',data); bpy.context.scene.collection.objects.link(drop)
    honey=bpy.data.materials.new('HoneyDrop_TranslucentAmber'); honey.use_nodes=True
    glass=honey.node_tree.nodes['Principled BSDF']
    color=(255,199,88)
    glass.inputs['Base Color'].default_value=tuple((v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4) for v in color)+(1,)
    glass.inputs['Transmission Weight'].default_value=.78
    glass.inputs['Roughness'].default_value=.12
    glass.inputs['IOR'].default_value=1.47
    glass.inputs['Alpha'].default_value=.78
    glass.inputs['Coat Weight'].default_value=.4
    glass.inputs['Coat Roughness'].default_value=.08
    data.materials.append(honey)
    layer=data.uv_layers.new(name=uv.name)
    for value in layer.data: value.uv=sample
    for p in data.polygons: p.use_smooth=True
    drop['appearance']='Light amber translucent honey, transmission 0.78, alpha 0.78, IOR 1.47'

    # A narrow curved cream reflection follows the upper-left surface. This
    # separate highlight retains its shape even under flat game lighting.
    positions=[]; highlight_faces=[]
    steps=18
    for i in range(steps+1):
        t=i/steps
        angle=.68 + 1.02*t
        z=top.z-height*(1-math.cos(angle))/2
        radius=.175*math.sin(angle)*(.65-.35*math.cos(angle))+.0012
        center=1.78 + .15*t
        width=.014 + .055*math.sin(math.pi*t)**.6
        for offset in (-width,width):
            a=center+offset
            positions.append((top.x+radius*math.cos(a),top.y+radius*math.sin(a),z))
    for i in range(steps): highlight_faces.append((2*i,2*i+1,2*i+3,2*i+2))
    streak_data=bpy.data.meshes.new('HoneyDropHighlight')
    streak_data.from_pydata(positions,[],highlight_faces); streak_data.update()
    streak=bpy.data.objects.new('HoneyDropHighlight',streak_data)
    bpy.context.scene.collection.objects.link(streak)
    layer=streak_data.uv_layers.new(name=uv.name)
    for value in layer.data: value.uv=sample
    white=bpy.data.materials.new('Honey_ReflectiveStreak'); white.use_nodes=True
    shader=white.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value=(1,.94,.76,1)
    shader.inputs['Roughness'].default_value=.16
    shader.inputs['Emission Color'].default_value=(1,.94,.76,1)
    shader.inputs['Emission Strength'].default_value=.18
    streak_data.materials.append(white)
    bpy.ops.object.select_all(action='DESELECT')
    streak.select_set(True); bpy.context.view_layer.objects.active=streak
    solid=streak.modifiers.new('Reflection film','SOLIDIFY'); solid.thickness=.0006
    bpy.ops.object.modifier_apply(modifier=solid.name)
    for p in streak.data.polygons: p.use_smooth=True
    tail['honeyTailStyle']='orange curl with separate translucent droplet and highlight'
