# -*- coding: utf-8 -*-
"""Write a PNG, with no dependencies at all.

WHY THIS IS ITS OWN FILE, AND IT IS NOT TIDINESS. It lived in
`make_animal_maps.py`, and three scripts imported it from there --
`bake_skin.py`, `bake_pattern.py` and `make_paint_blend.py` -- which meant
importing a 42 KB pattern generator to get one 12-line function.

THAT ALREADY COST A DAY. `make_animal_maps.py` called `main()` at module
scope, so every one of those imports REGENERATED NINE 1024-square maps before
returning. `bake_skin.py` appeared to hang for fifteen minutes writing nothing,
which is exactly what it was doing: somebody else's work, silently, on the way
to borrowing a function. Wrapping that call in `if __name__ == "__main__"` took
the import from forever to 0.02 seconds and was the right fix; this is the
other half, which is that the dependency should never have existed.

It also unblocks filing the scripts into folders. Every script here now depends
ONLY on the toolkit modules sitting beside `paths.py`, so no script has to know
where any other script has been put.

NO PILLOW, ON PURPOSE. Blender's bundled Python has no Pillow -- an earlier
version of `bake_skin.py` imported it at module scope and took the whole bake
down with `ModuleNotFoundError` AFTER the bake had been proved to work, which
is the worst possible time to break a script. `struct` and `zlib` are in every
Python there is, including Blender's.
"""
import struct
import zlib

# THE MARKING INK THE ANIMAL SHEETS ARE WRITTEN IN. One constant rather than a
# literal in each generator: a mask carries a SHAPE in alpha and exactly one
# RGB, and two generators disagreeing about that RGB by a couple of levels is
# invisible until two sheets are worn by the same animal.
INK = (14, 12, 14)


def png(path, rows, w, h, rgba):
    """`rows` is a list of `h` bytes-like rows, each `w * (4 if rgba else 3)`
    long. Filter byte 0 on every row -- no filtering, which costs a little size
    and removes the one part of the format that can be got subtly wrong."""
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6 if rgba else 2, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))
