# Pop the Pins: Roblox build

This is the in-game version of the kit one folder up. `Shared/Crack.luau` draws it.

- `housing.png`, `parts.png` and `buttons.png` are the twelve kit sprites. Each sprite is cropped to its display rect and packed into three atlases. None is over 1024 px, so Roblox never downscales them and the pixel rects stay valid.
- `atlas.json` lists every sprite's `[x, y, w, h]` in its sheet. `Crack.luau` copies these into `RECT`.
- `roblox-uploads.json` holds the uploaded image IDs, which `Crack.luau` copies into `ART`.
- The atlases are rebuilt with `python blender/ui/pack_pop_the_pins.py`. If the rects change, re-upload the sheets and update `ART` and `RECT` together.

One pin is one crack slice. The server still owns the sweep, the windows, the slices and the hit test. The client maps the marker onto the active pin's travel and the zone onto the notch, so a collar sitting in the notch is exactly a server hit. The only server change is `lock = crack.locks` in the `CrackState` payload, which feeds the "LOCK LV." header.

Verified in Studio Play on 2026-09-18:
- A real crack on a resident opened the panel with the correct name, lock level and pin count.
- The active pin moves and its notch tracks each slice.
- SET PIN landed a slice, and that pin seated in turquoise with its check.
- TAKE & RUN closed the panel.
- The steal and smash prompts hide while the panel is open and come back after.

Not yet tested: a phone-sized screen, and the miss sound heard in context.
