"""Runtime dial frame expressed in Blender's native pig coordinates."""
from pathlib import Path
import math,re
from mathutils import Vector
REPO=Path(__file__).resolve().parents[3]
code=(REPO/'src/ServerScriptService/Services/PiggyBank.luau').read_text(encoding='utf-8')
config=(REPO/'src/ReplicatedStorage/Shared/Config.luau').read_text(encoding='utf-8')
def constant(name):return float(re.search(r'local '+name+r' = ([0-9.]+)',code)[1])
SCALE=6
R=constant('BODY_R');Y=constant('BODY_Y');drop=constant('DIAL_Y')-Y
N=Vector((0,math.sqrt(R*R-drop*drop),drop)).normalized()
O=Vector((0,0,(Y-(.5+1.02*SCALE))/SCALE))
U=Vector((1,0,0));V=N.cross(U).normalized()
SEAT=O+N*((R+constant('MESH_DIAL_OUT'))/SCALE)
RADII=[float(r) for r in re.findall(r'name = "(?:Iron|Bronze|Steel|Gold)", metal = Color3.fromRGB\([^)]+\), radius = ([0-9.]+)',config)]
assert len(RADII)==4
BORE=(min(RADII)-constant('VAULT_COVER'))/SCALE
MAX_R=max(RADII)/SCALE
FRONT=constant('DIAL_THICK')/2/SCALE

def vault_blocked(tree,scale=1):
    # Keep the opening clear. Feathers may tuck under a closed door, but must
    # remain below its front face so they cannot show through the metal.
    for i in range(64):
        d=U*math.cos(i*math.tau/64)+V*math.sin(i*math.tau/64)
        for fraction in (0,.5,1):
            if tree.ray_cast((O+N*2+d*BORE*fraction)*scale,-N,1.30*scale)[0] is not None:return True
            if tree.ray_cast((SEAT+N*.8+d*MAX_R*fraction)*scale,-N,(.8-FRONT-.006)*scale)[0] is not None:return True
    return False
