#!/usr/bin/env python3
"""Write the SurfacePacks/*.model.json files for a batch of skins, from the ids.

    python tools/build_skin_packs.py --keys marble,rockslide,...        # dry run
    python tools/build_skin_packs.py --keys ... --go                    # writes

WHY A SCRIPT. A pack is four ids in a fixed shape, and this round is 34 of
them. Hand-writing that is 34 chances to paste one skin's ColorMap into
another's pack -- a mistake nothing errors on, because every id is a valid id
and the wrong coat simply renders. The ids come out of `import/asset-ids.csv`
(where tools/upload_images.py put them) and out of each skin's own
`roblox-uploads.json` where a pass uploaded outside that CSV, so the pack and
the upload record cannot disagree.

WHICH MAP A SHEET BECOMES IS READ OFF ITS NAME, and the naming convention is
the whole interface:

    <key>[_og_v1]_<part>_<map>.png      part is body|trim
                                        map  is color|emissive|metal|rough
    <key>-epic-v2-<part>.png            the epic-v2 pass's own names

An unrecognised name is refused loudly rather than dropped: a sheet that
silently fails to land in a pack is a map nobody notices is missing until the
pig is on a plinth.

EMISSIVE IS `EmissiveMaskContent` PLUS A STRENGTH, which is the route
`legend_dragon_body.model.json` already takes and the one the og-redesign was
authored for -- every epic and legendary in that batch ships a `*_emissive.png`
and no rare does, because those are exactly the tiers whose glow used to come
from `Material.Neon`. The strength here is a STARTING value, authored rather
than measured; the first pedestal render is where it gets tuned.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CSV_PATH = os.path.join(ROOT, "import", "asset-ids.csv")
PACKS = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "SurfacePacks")
PIGGIES = os.path.join(ROOT, "assets", "piggies")

# Which SurfaceAppearance property each map name fills.
SLOT = {
    "color": "ColorMap",
    "emissive": "EmissiveMaskContent",
    "metal": "MetalnessMap",
    "rough": "RoughnessMap",
    "normal": "NormalMap",
}

# The starting EmissiveStrength for a pack that carries a mask. Authored, not
# measured -- see the module docstring.
EMISSIVE_STRENGTH = {"epic": 0.9, "legendary": 1.2}

NAME_RE = re.compile(
    r"^(?P<key>[a-z0-9]+)"
    r"(?:_og_v1|-epic-v2)?"
    r"[-_](?P<part>body|trim)"
    r"(?:[-_](?P<map>color|emissive|metal|rough|normal))?"
    r"\.png$"
)


def parse_sheet(name: str):
    """(key, part, slot) for a sheet filename, or None if it is not one."""
    m = NAME_RE.match(name)
    if not m:
        return None
    # `<key>-epic-v2-body.png` carries no map word and means the colour map.
    return m.group("key"), m.group("part"), SLOT[m.group("map") or "color"]


def tier_of(key: str):
    for tier in ("common", "rare", "epic", "legendary", "unreleased"):
        if os.path.isdir(os.path.join(PIGGIES, tier, key)):
            return tier
    return None


def ids_for(keys: set):
    """{key: {part: {slot: id}}} gathered from the CSV and the upload records."""
    found = {}

    def put(key, part, slot, asset_id, where):
        if key not in keys:
            return
        aid = str(asset_id).strip()
        if not aid:
            return
        if not aid.startswith("rbxassetid://"):
            aid = "rbxassetid://" + aid.lstrip("/")
        slots = found.setdefault(key, {}).setdefault(part, {})
        if slot in slots and slots[slot] != aid:
            sys.exit(f"{key} {part} {slot}: two different ids ({slots[slot]} and {aid} from {where})")
        slots[slot] = aid

    with open(CSV_PATH, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            parsed = parse_sheet(row["upload_as"])
            if not parsed:
                continue
            put(parsed[0], parsed[1], parsed[2], row["current_asset_id"], "asset-ids.csv")

    # A pass that uploaded outside the CSV leaves its ids here instead.
    for tier in ("common", "rare", "epic", "legendary", "unreleased"):
        base = os.path.join(PIGGIES, tier)
        if not os.path.isdir(base):
            continue
        for key in os.listdir(base):
            rec = os.path.join(base, key, "roblox-uploads.json")
            if not os.path.exists(rec):
                continue
            data = json.load(open(rec, encoding="utf-8"))
            for role, asset in data.get("assets", {}).items():
                if asset.get("assetType") != "Image":
                    continue
                parsed = parse_sheet(os.path.basename(asset.get("source", "")))
                if not parsed:
                    continue
                put(parsed[0], parsed[1], parsed[2], asset.get("assetId"), rec)
    return found


def pack_for(slots: dict, tier: str) -> dict:
    props = {
        "AlphaMode": "Overlay",
        "ColorMap": slots.get("ColorMap", ""),
        "MetalnessMap": slots.get("MetalnessMap", ""),
        "RoughnessMap": slots.get("RoughnessMap", ""),
        "NormalMap": slots.get("NormalMap", ""),
    }
    if slots.get("EmissiveMaskContent"):
        props["EmissiveMaskContent"] = slots["EmissiveMaskContent"]
        props["EmissiveStrength"] = EMISSIVE_STRENGTH.get(tier, 0.6)
    return {"className": "SurfaceAppearance", "properties": props}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", required=True, help="comma-separated skin keys")
    ap.add_argument("--go", action="store_true", help="write the files (default is a dry run)")
    args = ap.parse_args()

    keys = {k.strip() for k in args.keys.split(",") if k.strip()}
    found = ids_for(keys)

    missing = sorted(keys - set(found))
    if missing:
        sys.exit("no ids found for: " + ", ".join(missing))

    # A MODEL-BASED LEGENDARY'S PACKS ARE CALLED `legend_<key>*` AND ARE NOT
    # WRITTEN HERE. dragon, phoenix, rainbowtiger and stormwolf are whole
    # models standing over a hidden pig, and their sheets are named
    # `<key>_body_color.png` like everyone else's -- so a careless --keys
    # dragon would write a `dragon.model.json` that nothing reads and leave
    # the real `legend_dragon_body.model.json` untouched. Nothing would error;
    # the dragon would simply go on wearing what it already wears.
    hijack = sorted(k for k in keys
                    if any(f.startswith(f"legend_{k}") for f in os.listdir(PACKS)))
    if hijack:
        sys.exit("these wear legend_* packs; edit those by hand: " + ", ".join(hijack))

    written = 0
    for key in sorted(found):
        tier = tier_of(key)
        for part in ("body", "trim"):
            slots = found[key].get(part)
            if not slots:
                print(f"  {key:12} {part:4} NO SHEETS -- skipped")
                continue
            if not slots.get("ColorMap"):
                sys.exit(f"{key} {part}: has maps but no ColorMap")
            name = key if part == "body" else f"{key}_trim"
            path = os.path.join(PACKS, f"{name}.model.json")
            pack = pack_for(slots, tier)
            extra = [k for k in slots if k != "ColorMap"]
            print(f"  {name:22} {slots['ColorMap']:30} {'+' + ','.join(sorted(extra)) if extra else ''}")
            if args.go:
                with open(path, "w", encoding="utf-8", newline="\n") as fh:
                    json.dump(pack, fh, indent=2)
                    fh.write("\n")
                written += 1
    print(f"\n{written} pack(s) written" if args.go else "\n(dry run; add --go)")


if __name__ == "__main__":
    main()
