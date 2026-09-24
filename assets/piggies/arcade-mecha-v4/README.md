# Mecha Player v4 review

Local review only. The installed game revision remains v2.

Changes: reopened the measured original coin slot through the accepted v3 crown; navy shoulder plates fitted to the shell with UV-painted shifted trapezoid warning stripes; recessed side and rear light panels; fitted ceramic face plate and navy cheek inserts; four navy body sockets/pistons and redesigned boots with recessed displays and flat angled belt markings.

Model: ../legendary/mechaplayer/package/arcade-v4/mechaplayer-arcade-v4.blend
Preview: http://127.0.0.1:8841/arcade-mecha-v4/index.html
Source: build.py executes geometry.py, starting from the preserved v3 blend. validate.py reopens and checks the saved result.

Validation: 87 closed accessory meshes, 21,524 accessory triangles. FBX round trips pass for accessories and complete model. Six-second motion loop closes within 0.000001. Checked 15 unobstructed coin paths, 510 crown rays outside the opening, 9 recessed-vent rays, eye clearance, packed shoulder textures, and unchanged base geometry/UVs.

Integration follow-up after review: match the preview eye seating (0.026 Blender units forward), account for boot soles at Z=-1.13, and preserve the two new shoulder color maps. No runtime configuration, upload IDs, or installed models changed for this revision.
