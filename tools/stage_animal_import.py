"""Stage every file the animal-crate import needs into ./import (untracked).

Names are taken from each package's own README rather than globbed, so review
renders never end up in a bulk upload.
"""
import csv
import io
import os
import shutil
import sys

ROOT = "assets/piggies"      # <tier>/<key>/package/ since 2026-09-22
OUT = "import"

COMMON = ["bee", "ladybird", "cow", "zebra", "giraffe", "leopard", "tiger", "snowleopard"]
RARE = ["strawberrycow", "cookiescream", "watermelon", "peppermint",
        "glacier", "bubblegumleopard", "honeycomb"]

# filename -> (target in Studio) for the four legendaries, per their READMEs.
LEGENDARY_MAPS = {
    "stormwolf": [
        ("stormwolf_body_color.png",    "Body + Tail  ColorMap"),
        ("stormwolf_body_emissive.png", "Body + Tail  EmissiveMaskContent"),
    ],
    "dragon": [
        ("dragon_body_color.png",     "Body  ColorMap"),
        ("dragon_trim_color.png",     "Snout/Ears/Legs/Tail  ColorMap"),
        ("dragon_body_emissive.png",  "Body  EmissiveMaskContent"),
        ("dragon_trim_emissive.png",  "Snout/Ears/Legs/Tail  EmissiveMaskContent"),
    ],
    "phoenix": [
        ("phoenix_color.png",    "all meshes  ColorMap (2048 atlas, PhoenixPalette UVs)"),
        ("phoenix_emissive.png", "all meshes  EmissiveMaskContent"),
    ],
    "rainbowtiger": [
        ("rainbowtiger-coat.png",            "Body  ColorMap (keep part tint white)"),
        ("rainbowtiger-stripe-emission.png", "Body  stripe glow mask"),
        ("rainbowtiger-charcoal-fur.png",    "EarFur  ColorMap"),
        ("beard-flow-color.png",             "CheekFur_-1/1, CheekFill_-1/1, BeardFur  ColorMap"),
        ("beard-flow-normal.png",            "same beard meshes  NormalMap"),
        ("rainbowtiger-tail-gradient.png",   "TailPlume  ColorMap"),
    ],
}

# Renamed on copy so a flat folder stays unambiguous. Original name kept in the CSV.
RENAME = {
    "beard-flow-color.png": "rainbowtiger-beard-flow-color.png",
    "beard-flow-normal.png": "rainbowtiger-beard-flow-normal.png",
}

MESHES = {  # skin -> (complete fbx, idle fbx or None, helper luau or None)
    "stormwolf":    ("stormwolf-complete.fbx",    None,                      "StormWolfLightning.luau"),
    "dragon":       ("dragon-complete.fbx",       "dragon-idle.fbx",         "DragonGlow.luau"),
    "phoenix":      ("phoenix-complete.fbx",      "phoenix-idle.fbx",        "PhoenixFrost.luau"),
    "rainbowtiger": ("rainbowtiger-complete.fbx", "rainbowtiger-idle.fbx",   None),
}

rows = []
missing = []


def src(tier, skin, name):
    return os.path.join(ROOT, tier, skin, "package", name)   # the tier IS the folder now


def take(tier, skin, name, role, target, bucket):
    p = src(tier, skin, name)
    if not os.path.exists(p):
        missing.append(p)
        return
    out_name = RENAME.get(name, name)
    dest_dir = os.path.join(OUT, bucket)
    os.makedirs(dest_dir, exist_ok=True)
    shutil.copy2(p, os.path.join(dest_dir, out_name))
    rows.append({
        "upload_as": out_name, "tier": tier, "skin": skin, "role": role,
        "assign_to": target, "source": p.replace("\\", "/"), "asset_id": "",
    })


for skin in COMMON:
    take("common", skin, f"{skin}_body_color.png", "colour", "Body  ColorMap", "textures")
    take("common", skin, f"{skin}_trim_color.png", "colour", "Snout/Ears/Legs/Tail  ColorMap", "textures")

for skin in RARE:
    take("rare", skin, f"{skin}_body_color.png", "colour", "Body  ColorMap", "textures")
    take("rare", skin, f"{skin}_trim_color.png", "colour", "Snout/Ears/Legs/Tail  ColorMap", "textures")
    take("rare", skin, f"{skin}_body_emissive.png", "emissive", "Body  EmissiveMaskContent", "textures")
    take("rare", skin, f"{skin}_trim_emissive.png", "emissive", "Snout/Ears/Legs/Tail  EmissiveMaskContent", "textures")

for skin, maps in LEGENDARY_MAPS.items():
    for name, target in maps:
        role = "emissive" if ("emissive" in name or "emission" in name) else (
            "normal" if "normal" in name else "colour")
        take("legendary", skin, name, role, target, "textures")

for skin, (complete, idle, helper) in MESHES.items():
    take("legendary", skin, complete, "meshes", "3D Importer, rig intact, 12 studs across", "meshes")
    if idle:
        take("legendary", skin, idle, "animation", "Animation Editor, on the main rig, publish + loop", "animations")
    if helper:
        take("legendary", skin, helper, "script", "ModuleScript, require(...).start(model)", "helpers")

os.makedirs(OUT, exist_ok=True)
with io.open(os.path.join(OUT, "asset-ids.csv"), "w", encoding="utf-8", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["upload_as", "tier", "skin", "role", "assign_to", "source", "asset_id"])
    w.writeheader()
    w.writerows(rows)

by_bucket = {}
for r in rows:
    b = "textures" if r["role"] in ("colour", "emissive", "normal") else r["role"]
    by_bucket[b] = by_bucket.get(b, 0) + 1

print("staged:", len(rows), "files")
for b, n in sorted(by_bucket.items()):
    print(f"  {b:12} {n}")
tiers = {}
for r in rows:
    if r["role"] in ("colour", "emissive", "normal"):
        tiers[r["tier"]] = tiers.get(r["tier"], 0) + 1
print("textures by tier:", tiers)
if missing:
    print("\nMISSING (not copied):")
    for m in missing:
        print("  ", m)
    sys.exit(1)
