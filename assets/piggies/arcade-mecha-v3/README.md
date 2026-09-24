# Mecha Player — review revision 3

The side/back armor now continues through the entire crown as one closed shell. It replaces the six old open-ended side shell panels and the rear spine strip. Fine navy seams sit above a continuous steel surface, so the body cannot show between them.

The two navy forehead pieces are replaced by one connected stepped plate, curved across the center between the ears.

Boots, guards, vents, turbines, materials and existing animation are retained. The base pig geometry and UVs are unchanged. The v2 files and installed game assets remain intact; this version is a review preview.

- [Review and before/after](index.html)
- [Blender](../legendary/mechaplayer/package/arcade-v3/mechaplayer-arcade-v3.blend)
- [Front](../legendary/mechaplayer/preview/arcade-v3/mechaplayer-v3-hero.png)
- [Rear](../legendary/mechaplayer/preview/arcade-v3/mechaplayer-v3-back.png)
- [Overhead](../legendary/mechaplayer/preview/arcade-v3/mechaplayer-v3-top.png)
- [Geometry report](../legendary/mechaplayer/package/arcade-v3/asset-report.json)
- [Coverage check](../legendary/mechaplayer/package/arcade-v3/coverage-check.json)

Rebuild with Blender in background mode using `build.py -- --skin mechaplayer`. `validate.py` checks crown coverage against the body and confirms that the forehead and shell are each a single connected mesh.
