#!/usr/bin/env python3
"""Write each skin's live pack ids back into assets/piggies/<tier>/<key>/manifest.json.

    python tools/record_skin_ids.py --keys marble,rockslide,...       # dry run
    python tools/record_skin_ids.py --keys ... --go

`import/README.md` ends with "afterwards the manifests are rebuilt so
`assets/piggies/<tier>/<key>/manifest.json` records the ids the sheets just
became". This is that step for a maps-only round, where the full rebuild
(`assets/piggies/og-redesign-v1/build_batch.py`) would need Blender and would
re-bake art that is already approved.

DERIVED FROM THE FILES RATHER THAN FROM THE UPLOAD LOG, which is the point: it
reads the `.model.json` that the game actually loads and the `Config.SKINS` row
that actually names it, so a manifest can only ever say what is really wired. A
manifest written from the uploader's output would still look right after
somebody edited a pack by hand.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PACKS = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "SurfacePacks")
PIGGIES = os.path.join(ROOT, "assets", "piggies")
CONFIG = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config.luau")
CSV = os.path.join(ROOT, "import", "asset-ids.csv")


def tier_of(key):
    for t in ("common", "rare", "epic", "legendary", "unreleased"):
        if os.path.isdir(os.path.join(PIGGIES, t, key)):
            return t
    return None


def sheet_for(aid, csv_rows, folder):
    """The file an id was uploaded from, and its hash, off the staging CSV."""
    for r in csv_rows:
        if r.get("current_asset_id") == aid:
            src = os.path.join(ROOT, r["source"])
            rel = os.path.relpath(src, folder).replace("\\", "/")
            digest = ""
            if os.path.exists(src):
                digest = hashlib.sha256(open(src, "rb").read()).hexdigest()
            return rel, digest
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", required=True)
    ap.add_argument("--go", action="store_true")
    args = ap.parse_args()

    import csv as csvmod
    with open(CSV, newline="", encoding="utf-8") as fh:
        csv_rows = list(csvmod.DictReader(fh))

    config = open(CONFIG, encoding="utf-8").read()
    config_lines = config.splitlines()

    for key in [k.strip() for k in args.keys.split(",") if k.strip()]:
        tier = tier_of(key)
        if not tier:
            sys.exit(f"{key}: no folder under assets/piggies/*/")
        folder = os.path.join(PIGGIES, tier, key)
        man_path = os.path.join(folder, "manifest.json")
        if not os.path.exists(man_path):
            sys.exit(f"{key}: no manifest.json")
        man = json.load(open(man_path, encoding="utf-8"))

        templates, sources = {}, {}
        for part, name in (("body", key), ("trim", f"{key}_trim")):
            path = os.path.join(PACKS, f"{name}.model.json")
            if not os.path.exists(path):
                continue
            pack = json.load(open(path, encoding="utf-8"))
            props = pack["properties"]
            templates[part] = {
                "path": f"src/ReplicatedStorage/Shared/SurfacePacks/{name}.model.json",
                "ids": {k: v for k, v in props.items() if k != "AlphaMode"},
                "alphaMode": props.get("AlphaMode", ""),
            }
            for slot, aid in props.items():
                if slot == "AlphaMode" or not isinstance(aid, str) or not aid.startswith("rbxassetid://"):
                    continue
                rel, digest = sheet_for(aid, csv_rows, folder)
                entry = {"role": f"{name} {slot}"}
                if rel:
                    entry["file"] = rel
                if digest:
                    entry["sha256"] = digest
                sources[aid] = entry

        if not templates:
            sys.exit(f"{key}: no packs found -- run tools/build_skin_packs.py first")

        # Where the Config rows are, so the manifest points at the real lines.
        def line_of(pattern):
            for i, line in enumerate(config_lines, 1):
                if re.search(pattern, line):
                    return i
            return None

        skin_line = line_of(r"^\t" + key + r" = \{$")
        pack_line = line_of(r'^\t' + key + r' = \{ name = ".*template = "' + key + r'"')
        block = ""
        if skin_line:
            m = re.search(r"\n\t" + key + r" = \{\n(?:.*?\n)*?\t\},\n", config)
            block = m.group(0) if m else ""

        def field(name):
            m = re.search(r"\b" + name + r' = "([^"]*)"', block)
            return m.group(1) if m else None

        man["templates"] = templates
        man["idSources"] = sources
        man["config"] = {
            "readFrom": "src/ReplicatedStorage/Shared/Config.luau",
            "skinsRow": {
                "line": skin_line,
                "name": field("name"),
                "rarity": field("rarity"),
                "surface": field("surface"),
                "chest": field("chest"),
                "pattern": "pattern = {" in block,
                "anim": "anim = {" in block,
                "fx": 'fx = "' in block,
            },
            "surfacePack": {"key": key, "line": pack_line,
                            "template": key, "trimTemplate": f"{key}_trim"},
            "status": "in Config.SKINS, wearing a SurfacePacks pair",
        }
        man["status"] = "Uploaded and installed (og-redesign-v1 maps round, 2026-09-23)"

        maps = len(sources)
        print(f"  {key:12} {tier:9} {maps} id(s), skins row line {skin_line}, pack line {pack_line}")
        if args.go:
            with open(man_path, "w", encoding="utf-8", newline="\n") as fh:
                json.dump(man, fh, indent=2)
                fh.write("\n")
    print("\n(dry run; add --go)" if not args.go else "\nmanifests updated")


if __name__ == "__main__":
    main()
