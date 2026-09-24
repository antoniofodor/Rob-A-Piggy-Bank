"""Architectural resize; gameplay stations keep their original vertical scale."""
import math

WIDTH = 60 / 38
HEIGHT = 32 / 22.55
LENGTH = 40 / 32

def dot(a, b):
    return sum(x*y for x, y in zip(a, b))

def unit(v):
    length = math.sqrt(dot(v, v))
    return [x/length for x in v], length

def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]

def scale_part(part, scale):
    part['position'] = [x*s for x, s in zip(part['position'], scale)]
    r = part['rotation']
    axes = [[r[row*3+col]*scale[row] for row in range(3)] for col in range(3)]
    # Preserve the exact endpoints of long roof/branch beams, with a rigid
    # orthonormal CFrame. Native parts cannot represent a sheared transform.
    y, sy = unit(axes[1])
    projection = dot(axes[0], y)
    x, sx = unit([axes[0][i]-projection*y[i] for i in range(3)])
    z = cross(x, y)
    sz = abs(dot(axes[2], z))
    part['rotation'] = [v for row in zip(x, y, z) for v in row]
    part['size'] = [v*s for v, s in zip(part['size'], (sx, sy, sz))]

def resize(templates):
    for name, template in templates.items():
        if name == 'Pedestal':
            # Space is for footwork. Keep the gameplay props and buttons small.
            continue
        scale = (WIDTH, HEIGHT, LENGTH if name == 'RoomShell' else 1)
        for part in template['parts']:
            scale_part(part, scale)
        for mount in template['mounts'].values():
            mount['position'] = [v*s for v, s in zip(mount['position'], scale)]
        if name == 'RoomShell':
            template['length'] = 40
            for key, mount in template['mounts'].items():
                if key.startswith('Slot_'):
                    mount['position'][0] = -18 if mount['position'][0] < 0 else 18
                    mount['position'][1] = .03
                    mount['position'][2] = -(8 + ((int(key[-2:])-1)%3)*12)
