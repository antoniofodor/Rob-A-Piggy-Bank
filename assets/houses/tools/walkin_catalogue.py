"""Walk-in conversion dimensions in Blender coordinates (studs, Z up).

Room bounds are deliberately inside the original silhouette. Higher exterior
storeys remain architectural until connected floors are designed separately.
"""
from house_paths import house_slug

# id: source revision, room (xmin,xmax,ymin,ymax,floor,ceiling), entry
# (centre X, front Y, threshold Z, clear width, straight clearance height).
SPECS = {
 'shack': (1,(-6.7,6.7,1.0,14.1,.55,9.05),(0,-.55,.55,5.8,7.8)),
 'cottage': (1,(-6.3,6.3,6,18,1.0,11.0),(0,-1.75,1.0,6.0,8.0)),
 'townhouse': (1,(-6.6,6.6,2,18,.95,9.0),(0,-.6,.95,5.8,7.25)),
 'mushroom': (1,(-5.5,5.5,3,14.5,.35,9.4),(0,-.6,.35,5.45,7.0)),
 'villa': (1,(-9.3,9.3,1,19,.65,9.0),(0,-.85,.65,5.8,7.6)),
 'treehouse': (2,(-7.8,7.8,.5,12.8,14.5,24.8),(0,-.65,14.5,5.7,8.5)),
 'manor': (1,(-10.3,10.3,1.6,22,1.6,12.6),(0,-.65,1.6,6.4,8.8)),
 'slime': (2,(-9.0,9.0,2.0,21.0,.5,12.65),(0,-.75,.5,6.0,8.5)),
 'modern': (1,(-6,6,9.5,20.5,3.2,10.8),(0,-4.6,1.5,6.0,8.0)),
 'neontower': (1,(-10.5,10.5,1.0,21,1.15,12.0),(0,-2.2,1.15,7.0,8.6)),
 'crystal': (1,(-5,6.8,3.1,14,1.05,8.8),(3.0,-.85,1.05,5.8,7.35)),
 'palace': (1,(-15,15,1.7,24,4.4,17.0),(0,-.75,4.4,7.0,10.0)),
 'skycastle': (1,(-15,15,2.1,27.5,3.2,16.0),(0,-5.1,3.2,8.0,10.0)),
 'galleon': (1,(-14,14,2,14,3.2,12.5),(0,-1.15,3.2,6.0,8.5)),
 'portal': (1,(-14.5,14.5,1.2,23,1.0,12.2),(-8.2,-.65,1.0,6.0,8.5)),
 'thundercloud': (1,(-12,12,9.1,23,5.1,17.0),(0,3.95,5.1,6.0,8.5)),
 'void': (1,(-15.5,15.5,3.2,22.7,1.6,11.8),(0,-.7,1.6,6.4,9.0)),
 'goldenpig': (1,(-11.5,11.5,8.5,20,1.6,12.5),(0,-.65,1.6,6.0,8.5)),
}
# Gloop already has a hollow shell, but its fused corner bulges intrude into
# the advertised rectangle; give its next revision a smaller, clear lining.
EXISTING={'mushroom','treehouse'}
# Approved Studio exterior sizes, captured from the runtime generator after
# the user's resize pass. Bake these into geometry BEFORE measuring the room;
# new walk-in revisions then use runtime display scale 1.0.
AUTHOR_SCALE={
 'shack':1,'cottage':1,'townhouse':1,'mushroom':1.5,'villa':1.4,
 'treehouse':1,'manor':1.37,'slime':1,'modern':1.31,'neontower':1.1,
 'crystal':1.55,'palace':1.23,'skycastle':1.08,'galleon':1.39,
 'portal':1.33,'thundercloud':1.28,'void':1.18,'goldenpig':1.38,
}
MATERIALS={
 'shack':((144,106,68),(183,145,100),(128,90,53)),
 'cottage':((177,128,63),(232,191,102),(53,117,111)),
 'townhouse':((119,83,60),(214,187,150),(57,85,99)),
 'mushroom':((124,84,49),(236,216,179),(103,64,39)),
 'villa':((130,104,60),(226,215,181),(68,111,51)),
 'treehouse':((141,98,57),(214,193,148),(101,66,39)),
 'manor':((109,88,107),(155,149,167),(100,62,88)),
 'slime':((90,128,65),(132,183,77),(176,107,50)),
 'modern':((210,189,145),(233,221,191),(55,137,150)),
 'neontower':((77,93,112),(145,166,181),(35,100,121)),
 'crystal':((108,92,122),(144,126,162),(84,49,106)),
 'palace':((163,197,224),(212,232,244),(40,105,175)),
 'skycastle':((136,127,153),(187,179,197),(115,73,48)),
 'galleon':((157,111,65),(125,83,49),(132,88,46)),
 'portal':((127,105,143),(205,192,209),(107,68,46)),
 'thundercloud':((106,122,149),(151,167,191),(70,83,119)),
 'void':((48,40,63),(76,64,93),(35,26,47)),
 'goldenpig':((194,146,50),(232,201,112),(147,100,35)),
}
def folder(slug,revision):return f'{house_slug(slug)}-v{revision}'
