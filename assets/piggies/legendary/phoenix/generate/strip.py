# -*- coding: utf-8 -*-
"""The four renders, side by side at twelve studs.
    python assets/piggies/legendary/phoenix/generate/strip.py
A skin is READ from the pavement and judged in a 700-pixel render, and those
are two different questions -- so the four views are downscaled to about what
a piggy subtends across a street and laid in one strip. Anything that survives
that is the skin; anything that does not is detail nobody will ever see.
"""
import os, sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
import paths
from PIL import Image

W = int(sys.argv[1]) if len(sys.argv) > 1 else 175
names = ("hero", "crown", "spine", "low")
ims = [Image.open(paths.render("view_phoenix_%s.png" % n)).resize((W, W),
       Image.LANCZOS) for n in names]
out = Image.new("RGB", (W * len(ims), W))
for i, im in enumerate(ims):
    out.paste(im, (i * W, 0))
out.save(paths.render("phoenix_strip.png"))
print("  wrote renders/phoenix_strip.png at %dpx a side" % W)
