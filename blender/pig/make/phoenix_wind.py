"""Bake the game's Ice Phoenix wind profile into the existing weighted rig."""
from pathlib import Path
import math
import re

REPO = Path(__file__).resolve().parents[3]

def profiles():
    # Read the runtime tuning directly so preview and game share timing/strength.
    source = (REPO / 'src/ReplicatedStorage/Shared/Legendary/Rigs.luau').read_text(encoding='utf-8')
    source = source.split('\tphoenix = {', 1)[1]
    result = {}
    for name, strength, delay, flutter in re.findall(
            r'name = "([^"]+)".*?wind = \{ strength = ([\d.]+), delay = ([\d.]+), flutter = ([\d.]+)', source, re.S):
        result[name] = tuple(map(float, (strength, delay, flutter)))
    assert set(result) == {'Tail','Mantle_L','Mantle_R','Crest_0','Crest_1','Crest_2'}, result
    return result

def angle(phase, profile):
    strength, delay, flutter = profile
    w = phase - math.tau * delay
    gust = (.5 - .5 * math.cos(w)) ** 2
    ripple = .65 * math.sin(5*w) + .35 * math.sin(9*w + .6)
    return math.radians(strength*gust + flutter*(.15+.85*gust)*ripple)

def animate(rig, scene):
    from mathutils import Quaternion, Vector
    tuning = profiles()
    scene.render.fps = 30
    scene.frame_start, scene.frame_end = 1, 121
    # Replace just rig rotation tracks, preserving the frost material animation.
    rig.animation_data_clear()
    for frame in range(1, 122):
        for bone in rig.pose.bones:
            bone.rotation_mode = 'QUATERNION'
            q = bone.bone.matrix_local.to_quaternion()
            a = angle(math.tau*(frame-1)/120, tuning[bone.name]) if bone.name in tuning else 0
            axis = Vector((0,0,1)) if bone.name == 'Tail' else Vector((-1,0,-.1)).normalized()
            bone.rotation_quaternion = q.inverted() @ Quaternion(axis, a) @ q
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
    action = rig.animation_data.action
    action.name = 'Phoenix_IcyWind'
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'
    scene.frame_set(1)
    return tuning
