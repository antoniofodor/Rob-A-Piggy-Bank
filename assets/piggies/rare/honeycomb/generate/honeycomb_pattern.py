"""Regular six-sided honey cells, replacing the inherited giraffe field."""
import math


def paint(nt, bsdf, spec):
    def rgba(rgb):
        return tuple(v / 255 / 12.92 if v / 255 <= .04045 else
                     ((v / 255 + .055) / 1.055) ** 2.4 for v in rgb) + (1,)

    nt.nodes.clear()
    output = nt.nodes.new('ShaderNodeOutputMaterial')
    shader = nt.nodes.new('ShaderNodeBsdfPrincipled')
    shader.inputs['Roughness'].default_value = .6
    nt.links.new(shader.outputs[0], output.inputs['Surface'])

    def calc(op, a, b=0):
        n = nt.nodes.new('ShaderNodeMath'); n.operation = op
        for value, socket in ((a, n.inputs[0]), (b, n.inputs[1])):
            if isinstance(value, (float, int)): socket.default_value = value
            else: nt.links.new(value, socket)
        return n.outputs[0]

    xyz = nt.nodes.new('ShaderNodeSeparateXYZ')
    position = nt.nodes.new('ShaderNodeNewGeometry')
    nt.links.new(position.outputs['Position'], xyz.inputs[0])
    # A spherical honeycomb avoids the squeezed flower at cylindrical poles.
    # The dual of a uniformly subdivided icosahedron supplies hexagonal cells
    # over the curved body, with the twelve necessary pentagonal junctions.
    # This changes only the baked colour; no tessellation is added to the pig.
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1)
    sites = [v.co.normalized().copy() for v in bm.verts]
    bm.free()
    combine = nt.nodes.new('ShaderNodeCombineXYZ')
    nt.links.new(xyz.outputs['X'], combine.inputs['X'])
    nt.links.new(calc('DIVIDE', xyz.outputs['Y'], 1.08), combine.inputs['Y'])
    nt.links.new(calc('DIVIDE', xyz.outputs['Z'], .96), combine.inputs['Z'])
    normalize = nt.nodes.new('ShaderNodeVectorMath'); normalize.operation = 'NORMALIZE'
    nt.links.new(combine.outputs[0], normalize.inputs[0])
    best, second = -2, -2
    for site in sites:
        dot = nt.nodes.new('ShaderNodeVectorMath'); dot.operation = 'DOT_PRODUCT'
        nt.links.new(normalize.outputs[0], dot.inputs[0]); dot.inputs[1].default_value = site
        value = dot.outputs['Value']
        second = calc('MAXIMUM', second, calc('MINIMUM', best, value))
        best = calc('MAXIMUM', best, value)
    field = calc('SUBTRACT', 1, calc('DIVIDE', calc('SUBTRACT', best, second), .038))
    ramp = nt.nodes.new('ShaderNodeValToRGB'); ramp.label = 'Amber cavities and golden hexagonal wax rims'
    stops = [(0, (181, 93, 13)), (.64, (204, 117, 22)), (.75, (146, 66, 8)),
             (.83, (236, 155, 24)), (.91, (255, 208, 86)), (1, spec['ink'])]
    ramp.color_ramp.interpolation = 'LINEAR'
    for i, (at, color) in enumerate(stops):
        stop = ramp.color_ramp.elements[i] if i < 2 else ramp.color_ramp.elements.new(at)
        stop.position = at; stop.color = rgba(color)
    nt.links.new(field, ramp.inputs[0])
    nt.links.new(ramp.outputs['Color'], shader.inputs['Base Color'])
    return shader
