"""Join face and flank markings by blending distances to their stroke edges.

Keep the two periodic fields separate: mixing their phases creates pinstripes,
and switching their binary masks clips every stroke on the same plane. Instead
blend their signed edge distances through a broad, slightly irregular shoulder
region, then threshold once. This bends and tapers full-colour strokes without
crosshatching or an opacity fade. Used by generators and existing scenes.
"""

VERSION = 2


def soften_stripe_transition(material):
    if not material or not material.use_nodes:
        return False
    if material.get('stripe_transition_version') == VERSION:
        return False
    nt = material.node_tree

    def find(label):
        matches = [n for n in nt.nodes if n.label == label]
        if len(matches) != 1:
            raise ValueError(f'{material.name}: expected one {label!r}, got {len(matches)}')
        return matches[0]

    labels = {n.label for n in nt.nodes}
    tiger = 'inside a body stripe?' in labels
    zebra = 'rings: how far round the pole' in labels
    if not (tiger or zebra):
        return False
    for node in list(nt.nodes):
        if node.label.startswith('Shoulder:'):
            nt.nodes.remove(node)

    def math(op, label, *values):
        n = nt.nodes.new('ShaderNodeMath')
        n.operation = op
        n.label = 'Shoulder: ' + label
        n.location = (1500, -180 * len([x for x in nt.nodes if x.label.startswith('Shoulder:')]))
        for socket, value in zip(n.inputs, values):
            if isinstance(value, (int, float)):
                socket.default_value = value
            else:
                nt.links.new(value, socket)
        return n.outputs[0]

    def ramp(value, lo, hi, label):
        n = nt.nodes.new('ShaderNodeMapRange')
        n.label = 'Shoulder: ' + label
        n.interpolation_type = 'SMOOTHSTEP'
        n.clamp = True
        n.inputs['From Min'].default_value = lo
        n.inputs['From Max'].default_value = hi
        n.inputs['To Min'].default_value = 0
        n.inputs['To Max'].default_value = 1
        nt.links.new(value, n.inputs['Value'])
        return n.outputs['Result']

    selector = find('in front of the ears?')
    y = selector.inputs['Value'].links[0].from_socket
    # Low-frequency width noise staggers the tips without adding fine detail.
    variation = find('1 +- vary').outputs[0]
    offset = math('MULTIPLY_ADD', 'stagger the tips', variation, .12, -.12)
    shoulder_y = math('ADD', 'curved transition', y, offset)
    body_weight = ramp(shoulder_y, -.72, -.22, 'body grows through shoulder')

    def edge_distance(distance, width, label):
        safe_width = math('MAXIMUM', label + ' nonzero width', width, .00001)
        relative = math('DIVIDE', label + ' relative distance', distance, safe_width)
        return math('SUBTRACT', label + ' edge distance', relative, 1)

    if tiger:
        # The old minimum-width switch also squared off narrow endpoints.
        # Ease widths below that threshold to zero instead of dropping them.
        for field in ('body', 'head'):
            gate = find(field + ': wide enough to draw?')
            width = gate.inputs[0].links[0].from_socket
            cutoff = gate.inputs[1].default_value
            ease = ramp(width, cutoff * .5, cutoff,
                        field + ' continuous fine tips')
            nt.links.new(ease, find(field + ': WIDTH OR NOTHING').inputs[1])
        body = find('inside a body stripe?')
        head = find('inside a head stroke?')
        body_width = find('body: WIDTH OR NOTHING').outputs[0]
        head_width = find('head: WIDTH OR NOTHING').outputs[0]
        nt.links.new(body_width, body.inputs[1])
        nt.links.new(head_width, head.inputs[1])
        # Preserve each colourway's muzzle clearance while morphing its field.
        head_width = math('MULTIPLY', 'muzzle clearance', head_width,
                          find('clean round the muzzle').outputs['Result'])
        body_edge = edge_distance(body.inputs[0].links[0].from_socket, body_width, 'body')
        head_edge = edge_distance(head.inputs[0].links[0].from_socket, head_width, 'head')
        destination = find('every mask, multiplied together').inputs[0]
    else:
        jitter = find('BAND PHASE').inputs[1].links[0].from_socket
        width = find('WIDTH HERE').outputs[0]

        def band(label):
            phase = math('ADD', label + ' jitter', find(label).outputs[0], jitter)
            fraction = math('FRACT', label + ' period', phase)
            centered = math('SUBTRACT', label + ' centre', fraction, .5)
            absolute = math('ABSOLUTE', label + ' distance', centered)
            return math('MULTIPLY', label + ' band', absolute, 2)

        body_edge = edge_distance(band('rings: how far round the pole'), width, 'body')
        head_edge = edge_distance(band('meridians: which way round'), width, 'head')
        destination = find('BAND MASK').inputs[0]

    delta = math('SUBTRACT', 'body minus head distance', body_edge, head_edge)
    blended = math('MULTIPLY_ADD', 'continuous stroke edges', delta, body_weight, head_edge)
    joined = math('LESS_THAN', 'solid joined stripes', blended, 0)
    nt.links.new(joined, destination)

    material['stripe_transition_version'] = VERSION
    return True
