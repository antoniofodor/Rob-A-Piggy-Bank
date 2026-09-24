"""Stage every piggy-skin file the designer has to upload into ./import (untracked).

Rebuilds `import/` as a FLAT, upload-ready folder -- `textures/` for bulk
image upload through the Asset Manager, `meshes/` for the 3D Importer -- plus
`asset-ids.csv` and `README.md`, all derived from the same walk so the CSV and
the files cannot disagree. Run from the repo root:

    python tools/stage_import.py

Everything under `import/` is a COPY; the sources stay where they are:

  * `assets/piggies/<tier>/<key>/manifest.json`  -- which sheets each skin's
    SurfacePacks pack (or legend_* pack) references, the live ids, and which
    file each id was uploaded from.
  * `blender/pig/renders/closed-back-test/UPLOADS.md` -- the closed-back pass:
    the body mesh and the legendary rebuilds.
  * `assets/loot-bag/UPLOADS.md` -- the seven loot-bag meshes.
  * `src/ReplicatedStorage/Shared/Config.luau` -- read ONLY to fill
    `current_asset_id` for the mesh rows (`PIGGY_MESH`, `LEGENDARIES`).

Supersedes `tools/stage_animal_import.py`, which staged the package folders by
hand-kept lists and predates the closed-back pass and the per-tier manifests.

STATUS RULES (the `status` column):
  re-upload     the referenced sheet changed since the live id was uploaded:
                a `.open-hatch.png` / `.before-closedback.png` sibling exists
                and its bytes differ from the current file; or the manifest's
                recorded sha256 no longer matches the file. Also every mesh
                the closed-back pass re-exported.
  already-live  the live id was uploaded from bytes identical to the file
                staged here. Copied anyway so the designer can see the whole
                set, but there is nothing to do for these rows.
  new           no id exists anywhere: lion (its model.json is not written
                yet), the loot-bag parts, and every sheet of a skin that has
                no SurfacePacks pack -- the unreleased tier, and the two rows
                (magma, stormstone) still on a code-built pattern. The
                `assign_to` column says which of those it is.

NOT STAGED, on purpose: `*_alpha.png` (bake_alpha masks folded into a colour
sheet by apply_alpha.py, never uploaded as-is), dragon's `legacy` painted bake
(the manifest lists it; nothing in the game reads it), the plain-pig
`sheets/` of phoenix and rainbowtiger (their live packs read the package
atlases, which are byte-identical to the pre-rebuild ones), review renders,
idle-animation FBXs and helper scripts (not part of this round).

The `.apikey` file in `import/` is left exactly where it is and is never read.
"""
from __future__ import annotations

import csv
import hashlib
import io
import json
import os
import re
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PIGGIES = os.path.join(ROOT, "assets", "piggies")
OUT = os.path.join(ROOT, "import")
CONFIG = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config.luau")

TIERS = ["common", "rare", "epic", "legendary", "unreleased"]

# The closed-back pass (blender/pig/renders/closed-back-test/UPLOADS.md).
BODY_OBJ = "blender/pig/renders/closed-back-test/full/pig_body_closedback.obj"
BODY_ROW = "Config.PIGGY_MESH Body id -- new row: offset (0, 6.62, 0), size (12, 11.52, 12.96)"

# Which meshes inside each legendary's <key>-complete.fbx the pass re-exported
# (UPLOADS.md section 3), and the Config.LEGENDARIES row each feeds.
LEGENDARY_REEXPORT = {
    "dragon": ["Body", "Dragon_Root_ScaleDark", "Dragon_Root_ScaleLit",
               "Dragon_Root_ScaleMid", "Dragon_Root_ScaleOlive"],
    "phoenix": ["Body"],
    "rainbowtiger": ["Body"],
}
LEGENDARY_NEW_ROWS = {
    ("dragon", "Body"): "offset (0, 6.62, 0) size (12, 11.52, 12.96)",
    ("dragon", "Dragon_Root_ScaleDark"): "offset (-0.0146, 7.5566, 0.0635) size (12.2341, 13.6837, 13.1101)",
    ("dragon", "Dragon_Root_ScaleLit"): "offset (-0.0297, 7.4115, 0.0054) size (12.2067, 13.3718, 13.1936)",
    ("dragon", "Dragon_Root_ScaleMid"): "offset (0.0008, 7.4386, 0.0012) size (12.2593, 13.4282, 13.2436)",
    ("dragon", "Dragon_Root_ScaleOlive"): "offset (0.0831, 6.6389, -0.8067) size (12.0577, 11.6871, 11.5504)",
    ("phoenix", "Body"): "offset (0, 6.62, 0) size (12, 11.52, 12.96)",
    ("rainbowtiger", "Body"): "offset (0, 6.62, 0) size (12, 11.52, 12.96)",
}
# Not in the pass; own Meshy body, handled by hand. Staged so the FBX is to hand.
LEGENDARY_MANUAL = ["stormwolf"]

# The loot bag (assets/loot-bag/UPLOADS.md), in Config.LOOT_MESH row order.
LOOT_BAG = [
    ("loot-bag-cloth.fbx", "Bag"), ("loot-bag-lining.fbx", "Lining"),
    ("loot-bag-rope.fbx", "Rope"), ("loot-bag-gold.fbx", "Gold"),
    ("loot-bag-golddark.fbx", "GoldDark"), ("loot-bag-goldlight.fbx", "GoldLight"),
    ("loot-bag-nostril.fbx", "Nostril"),
]

SKIP_SUFFIXES = (".open-hatch.png", ".before-closedback.png", "_alpha.png")

CSV_FIELDS = ["upload_as", "tier", "skin", "role", "assign_to", "source",
              "current_asset_id", "status"]


def rel(p: str) -> str:
    return os.path.relpath(p, ROOT).replace("\\", "/")


def sha256(p: str) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def map_role(slot: str) -> str:
    slot = slot.lower()
    for word, role in (("color", "colour"), ("emissive", "emissive"),
                       ("normal", "normal"), ("roughness", "roughness"),
                       ("metalness", "metalness")):
        if word in slot:
            return role
    return "colour"


def sibling_before(path: str) -> str | None:
    """The file the live id was uploaded from, if the pass kept one beside it."""
    for suffix in (".open-hatch.png", ".before-closedback.png"):
        cand = path[:-4] + suffix
        if os.path.exists(cand):
            return cand
    return None


# --------------------------------------------------------------------------
# Config.luau: the mesh ids, read and never written.
# --------------------------------------------------------------------------

def read_config_mesh_ids() -> tuple[str, dict[str, dict[str, str]]]:
    with io.open(CONFIG, encoding="utf-8") as fh:
        text = fh.read()
    # PIGGY_MESH Body id: the first `id = "..."` after `part = "Body"` in that table.
    body_id = ""
    m = re.search(r'Config\.PIGGY_MESH\s*=\s*\{(.*?)\n\}', text, re.S)
    if m:
        b = re.search(r'part\s*=\s*"Body".*?id\s*=\s*"(\d*)"', m.group(1), re.S)
        if b:
            body_id = b.group(1)
    # LEGENDARIES: key = { { part = "...", id = "..." }, ... }
    legend: dict[str, dict[str, str]] = {}
    m = re.search(r'Config\.LEGENDARIES\s*=\s*\{(.*?)\n\}', text, re.S)
    if m:
        block = m.group(1)
        for km in re.finditer(r'\n\t(\w+)\s*=\s*\{', block):
            key = km.group(1)
            start = km.end()
            nxt = re.search(r'\n\t(\w+)\s*=\s*\{', block[start:])
            body = block[start:start + nxt.start()] if nxt else block[start:]
            legend[key] = dict(re.findall(r'part\s*=\s*"([^"]+)",\s*id\s*=\s*"(\d*)"', body))
    return body_id, legend


# --------------------------------------------------------------------------
# The walk.
# --------------------------------------------------------------------------

rows: list[dict[str, str]] = []
problems: list[str] = []      # things a manifest names that are not on disk
staged_sources: dict[str, str] = {}   # upload_as -> source (collision check)
renamed: list[tuple[str, str]] = []


def stage(src: str, bucket: str, tier: str, skin: str, role: str,
          assign_to: str, current_id: str, status: str, upload_as: str | None = None) -> None:
    if not os.path.exists(src):
        problems.append(f"{rel(src)} (named for {skin}/{role}) is not on disk")
        return
    name = upload_as or os.path.basename(src)
    if name in staged_sources and staged_sources[name] != rel(src):
        base, ext = os.path.splitext(name)
        new = f"{skin}_{base}{ext}" if not base.startswith(skin) else f"{base}_{tier}{ext}"
        renamed.append((name, new))
        name = new
    staged_sources[name] = rel(src)
    dest_dir = os.path.join(OUT, bucket)
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, name)
    if not (os.path.exists(dest) and sha256(dest) == sha256(src)):
        shutil.copy2(src, dest)
    rows.append({
        "upload_as": name, "tier": tier, "skin": skin, "role": role,
        "assign_to": assign_to, "source": rel(src),
        "current_asset_id": current_id, "status": status,
    })


def stage_skin(tier: str, skin_dir: str) -> None:
    mpath = os.path.join(skin_dir, "manifest.json")
    with io.open(mpath, encoding="utf-8") as fh:
        man = json.load(fh)
    key = man["key"]
    templates = man.get("templates") or {}
    id_sources = man.get("idSources") or {}
    legacy = set(man.get("legacy", {}).get("files", []))

    # 1. Everything a pack references TODAY, by the id it carries.
    referenced: set[str] = set()
    for asset_id, info in id_sources.items():
        recorded = info["file"]
        # The manifest names the file the id was UPLOADED FROM; the file to
        # stage is the CURRENT sheet, which is the same name with the pass's
        # suffix stripped.
        current = recorded
        for suffix in (".open-hatch.png", ".before-closedback.png"):
            if current.endswith(suffix):
                current = current[:-len(suffix)] + ".png"
        src = os.path.join(skin_dir, current)
        referenced.add(current)
        if not os.path.exists(os.path.join(skin_dir, recorded)):
            problems.append(f"{rel(os.path.join(skin_dir, recorded))} (manifest idSources for {asset_id}) is not on disk")
        if not os.path.exists(src):
            problems.append(f"{rel(src)} (current sheet behind {asset_id}) is not on disk")
            continue
        before = sibling_before(src)
        if before is not None:
            status = "already-live" if sha256(before) == sha256(src) else "re-upload"
        else:
            status = "already-live" if info.get("sha256") == sha256(src) else "re-upload"
        role_text = info.get("role", "")
        role = map_role(role_text)
        pack = role_text.split(" ")[0]
        slot = role_text.split(" ")[-1]
        tmpl = templates.get(pack) or {}
        target = tmpl.get("path", "") if tmpl else ""
        assign = f"{target} {slot}".strip() if target else role_text
        stage(src, "textures", tier, key, role, assign, asset_id, status)

    # 2. A pack that exists in Config but whose model.json is not written yet
    #    (lion): the sheets are NEW and go to the slot the pack will carry.
    for pack, tmpl in templates.items():
        if tmpl and tmpl.get("ids"):
            continue
        part = "trim" if pack.endswith("trim") else "body"
        src = os.path.join(skin_dir, "sheets", f"{key}_{part}_color.png")
        if f"sheets/{key}_{part}_color.png" in referenced:
            continue
        referenced.add(f"sheets/{key}_{part}_color.png")
        target = (tmpl or {}).get("path", f"src/ReplicatedStorage/Shared/SurfacePacks/{key}{'_trim' if part == 'trim' else ''}.model.json")
        exists = os.path.exists(os.path.join(ROOT, target))
        note = "" if exists else " (model.json NOT WRITTEN YET; upload, then the coordinator creates it)"
        stage(src, "textures", tier, key, "colour", f"{target} ColorMap{note}", "", "new")

    # 3. A skin with NO pack at all: every current sheet, marked by why.
    if not templates:
        if man.get("tier") == "unreleased" or "NOT in Config.SKINS" in (man.get("config") or {}).get("status", ""):
            why = "UNRELEASED: no Config.SKINS row yet -- upload only when the row lands"
        else:
            why = "UNWIRED: Config row still on a code-built pattern/anim; no SurfacePacks pack yet"
        sheets_dir = os.path.join(skin_dir, "sheets")
        for name in sorted(os.listdir(sheets_dir)) if os.path.isdir(sheets_dir) else []:
            if not name.endswith(".png") or name.endswith(SKIP_SUFFIXES):
                continue
            if f"sheets/{name}" in legacy or f"sheets/{name}" in referenced:
                continue
            part = "trim" if "_trim_" in name else "body"
            slot = {"colour": "ColorMap", "emissive": "EmissiveMaskContent", "normal": "NormalMap",
                    "roughness": "RoughnessMap", "metalness": "MetalnessMap"}[map_role(name)]
            stage(os.path.join(sheets_dir, name), "textures", tier, key, map_role(name),
                  f"{why}; would be {part} {slot}", "", "new")
    elif man.get("tier") == "unreleased":
        # metal: a live shared pack under unreleased/. Its referenced sheets are
        # already staged above; the older pack beside them is not referenced.
        pass

    # 4. Cross-check: every file the manifest LISTS under sheets/ is on disk,
    #    and every referenced template path exists.
    for name in (man.get("files") or {}).get("sheets", []):
        if not os.path.exists(os.path.join(skin_dir, "sheets", name)):
            problems.append(f"{rel(os.path.join(skin_dir, 'sheets', name))} (listed in manifest files.sheets) is not on disk")
    for pack, tmpl in templates.items():
        if tmpl and tmpl.get("path") and tmpl.get("ids") and not os.path.exists(os.path.join(ROOT, tmpl["path"])):
            problems.append(f"{tmpl['path']} (manifest templates.{pack}) is not on disk")


def stage_meshes(body_id: str, legend: dict[str, dict[str, str]]) -> None:
    # The closed-back body.
    stage(os.path.join(ROOT, BODY_OBJ), "meshes", "-", "pig", "mesh",
          BODY_ROW, f"rbxassetid://{body_id}" if body_id else "", "re-upload")
    # The legendary rebuilds: one row per mesh the pass re-exported, all from
    # the one FBX (the 3D Importer hands back one id per part).
    for key, parts in LEGENDARY_REEXPORT.items():
        fbx = os.path.join(PIGGIES, "legendary", key, "package", f"{key}-complete.fbx")
        for part in parts:
            cur = legend.get(key, {}).get(part, "")
            stage(fbx, "meshes", "legendary", key, "mesh",
                  f"Config.LEGENDARIES.{key} {part} id -- new row: {LEGENDARY_NEW_ROWS[(key, part)]}",
                  f"rbxassetid://{cur}" if cur else "", "re-upload")
        fbm = fbx[:-4] + ".fbm"
        if os.path.isdir(fbm):
            shutil.copytree(fbm, os.path.join(OUT, "meshes", os.path.basename(fbm)), dirs_exist_ok=True)
    for key in LEGENDARY_MANUAL:
        fbx = os.path.join(PIGGIES, "legendary", key, "package", f"{key}-complete.fbx")
        parts = legend.get(key, {})
        cur = parts.get("Body", "")
        stage(fbx, "meshes", "legendary", key, "mesh",
              f"Config.LEGENDARIES.{key} -- NOT in the closed-back pass (own Meshy body, by hand); "
              f"all {len(parts)} meshes live, staged for reference only",
              f"rbxassetid://{cur}" if cur else "", "already-live")
        fbm = fbx[:-4] + ".fbm"
        if os.path.isdir(fbm):
            shutil.copytree(fbm, os.path.join(OUT, "meshes", os.path.basename(fbm)), dirs_exist_ok=True)
    # The loot bag.
    for name, part in LOOT_BAG:
        stage(os.path.join(ROOT, "assets", "loot-bag", "parts", name), "meshes", "-", "loot-bag",
              "mesh", f"Config.LOOT_MESH {part} id (rows in assets/loot-bag/UPLOADS.md; all seven in ONE edit)",
              "", "new")


# --------------------------------------------------------------------------
# Output.
# --------------------------------------------------------------------------

def write_csv() -> None:
    # THE SHEET IS HAND-FILLED AFTER IT IS GENERATED, and a regeneration that
    # forgot that wiped 37 pasted ids once (2026-09-23). A row whose existing
    # status is `uploaded` (a value this script never emits -- it is what the
    # id read-back and tools/upload_images.py write) keeps its id and status;
    # everything else is rederived from the walk. Keyed on the upload name plus
    # the role's assign_to, because the dragon FBX yields five rows for one file.
    path = os.path.join(OUT, "asset-ids.csv")
    kept = {}
    if os.path.exists(path):
        with io.open(path, newline="", encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                if r.get("status") == "uploaded":
                    kept[(r["upload_as"], r["assign_to"])] = r
    carried = 0
    for r in rows:
        prior = kept.get((r["upload_as"], r["assign_to"]))
        if prior is None and r["role"] == "mesh":
            # A mesh row's assign_to carries the seat, which a re-export moves;
            # fall back to the upload name alone when that is unambiguous.
            same = [v for (name, _), v in kept.items() if name == r["upload_as"]]
            prior = same[0] if len(same) == 1 else None
        if prior is not None:
            r["current_asset_id"] = prior["current_asset_id"]
            r["status"] = "uploaded"
            carried += 1
    if carried:
        print(f"kept {carried} hand-filled id(s) from the existing sheet")
    with io.open(path, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=CSV_FIELDS)
        w.writeheader()
        w.writerows(rows)


def counts() -> dict:
    c = {"textures": 0, "meshes_rows": 0, "meshes_files": 0}
    files = set()
    for r in rows:
        if r["role"] == "mesh":
            c["meshes_rows"] += 1
            files.add(r["upload_as"])
        else:
            c["textures"] += 1
    c["meshes_files"] = len(files)
    by_status = {}
    for r in rows:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
    c["by_status"] = by_status
    c["re_upload_textures"] = [r["upload_as"] for r in rows if r["status"] == "re-upload" and r["role"] != "mesh"]
    return c


def write_readme(ignored: bool) -> None:
    c = counts()
    re_tex = "\n".join(f"  {n}" for n in c["re_upload_textures"])
    text = f"""# `import/` -- the upload staging folder (rebuilt {__import__('datetime').date.today().isoformat()})

Flat, upload-ready COPIES of every piggy-skin file the designer has to put
through Studio. Nothing here is a source: the sources are
`assets/piggies/<tier>/<key>/`, `blender/pig/renders/closed-back-test/full/`
and `assets/loot-bag/parts/`, and this whole folder is regenerated by

    python tools/stage_import.py

so the files and `asset-ids.csv` cannot disagree. **This folder is untracked
and disposable**: `.gitignore` line 47 ignores `import/` outright
({'confirmed by git check-ignore' if ignored else 'NOTE: git check-ignore did NOT confirm this -- check .gitignore'}).
Delete it whenever you like and run the script again. The only thing in here
that is not a copy is `.apikey`, which the script never reads, moves or
prints; leave it alone.

## What is here

| folder | files | for |
|---|---|---|
| `textures/` | {c['textures']} | bulk image upload through **Asset Manager** |
| `meshes/` | {c['meshes_files']} | one at a time through the **3D Importer** ({c['meshes_rows']} CSV rows, because one FBX yields several ids) |
| `asset-ids.csv` | | one row per upload; the sheet you fill in |

Status column: **{c['by_status'].get('re-upload', 0)} re-upload**,
**{c['by_status'].get('new', 0)} new**, **{c['by_status'].get('already-live', 0)} already-live**.

`already-live` rows are here so the set is complete; the live id was uploaded
from bytes identical to the file, so **skip them**. `new` rows have never
had an id. `re-upload` rows changed since their live id was uploaded.

## What is NEW or CHANGED since the closed-back pass and MUST be re-uploaded

This is the round `blender/pig/renders/closed-back-test/UPLOADS.md` and
`assets/loot-bag/UPLOADS.md` describe:

* **The closed-back body mesh** -- `meshes/pig_body_closedback.obj` ->
  `Config.PIGGY_MESH` Body (new offset/size on the row, see the CSV).
* **The 15 base body colour sheets** re-baked on the closed body
  (bee, ladybird, zebra, tiger, cow, giraffe, leopard, snowleopard,
  strawberrycow, cookiescream, watermelon, peppermint, glacier,
  bubblegumleopard, honeycomb) -> each `SurfacePacks/<key>.model.json` ColorMap.
* **Diamond's three body maps** (colour, normal, roughness) -> `diamond.model.json`.
* **The legendary meshes**: dragon `Body` + the four `Dragon_Root_Scale*`
  meshes, phoenix `Body`, rainbowtiger `Body` -- each out of its
  `<key>-complete.fbx` in `meshes/`.
* **Dragon's two sheets** `dragon_body_color.png` / `dragon_body_emissive.png`
  -> `legend_dragon_body.model.json`.
* **The seven loot-bag parts** -> `Config.LOOT_MESH` (brand new; all seven
  ids go into Config in ONE edit or the bag stays on primitives).
* **Lion's body + trim sheets** are `new` too: `lion.model.json` does not
  exist yet, so upload them and the coordinator creates the pack.

Every texture row the script classified as `re-upload`, for cross-checking:
{re_tex}

Trim sheets are unchanged everywhere (the fill never touches the trim mesh);
phoenix's atlas and every rainbowtiger sheet are byte-identical to what is
live. Those rows read `already-live`.

Rows whose `assign_to` starts **UNRELEASED** (koi, patched, piggybank,
raptor, spotty) or **UNWIRED** (magma, stormstone) have no pack reading them
today. (`metal/` is the live `bands` pack, not a skin: its three referenced
sheets are staged as `already-live`; its `pig_metal_color.png` and
`pig_value_ladder.png` are an older overlay pack and a value ladder that no
pack names, and are deliberately not here.) They are staged so the set is
complete; uploading them now only spends an upload under your own account
(see CLAUDE.md on generated-asset moderation) for an id nothing will read
yet. Your call.

## Procedure 1: the images (Asset Manager, bulk)

1. Studio -> View -> Asset Manager -> Images -> **Import** (the folder icon).
2. Multi-select everything in `import/textures/` you intend to upload -- sort
   the CSV by `status`, take the `re-upload` and `new` rows. Same names as the
   CSV's `upload_as`; nothing was renamed{' except: ' + ', '.join(f'{a} -> {b}' for a, b in renamed) if renamed else ''}.
3. Every image is moderated under your account. Upload once, not per attempt.
4. When they clear, each shows its id in the Asset Manager; paste it into the
   CSV's `current_asset_id` for that row (keep the `rbxassetid://` form; the
   model.json files carry it that way).

## Procedure 2: the meshes (3D Importer, one file at a time)

For each FBX / OBJ in `import/meshes/`:

1. Studio -> Avatar (or Home) -> **Import 3D** -> pick the file.
2. **Rig intact** for the legendary FBXs (keep the armature; do not flatten),
   mesh names preserved -- the game finds parts by name.
3. **Body is 12 studs across.** If the importer offers a scale, keep uniform
   scale so the body comes in at 12 wide; the Config rows in the CSV's
   `assign_to` give the offset and size each mesh must measure.
4. Upload; the imported Model's MeshParts carry the new ids in their `MeshId`.
   For the dragon, the FBX yields 24 parts and only five are on the CSV
   (`Body` and the four `Dragon_Root_Scale*`): those five ids are the ones to
   paste. For the loot bag, import each of the seven parts as its own
   MeshPart and check which way the coin faces before filling in the rest
   (`assets/loot-bag/UPLOADS.md`, "What is not done").
5. The FBXs reference a `<key>-complete.fbm` folder that does not exist: the
   maps are packed inside the FBX and separately staged in `textures/`.
   Assign the SurfaceAppearance maps by id, not from the import.
6. `stormwolf-complete.fbx` is `already-live` and outside the closed-back
   pass (own Meshy body, by hand); it is here only so the file is to hand.

## What to paste back where

* Put each new id in the CSV's **`current_asset_id`** column on its row --
  that column becomes the new truth. Do not edit Config or any model.json
  yourself.
* Hand the CSV to the **coordinator session that owns `Config.luau` and the
  SurfacePacks model.json files**. It applies the ids: the `assign_to`
  column names the exact file and slot (`.model.json ColorMap`, or the
  `Config.PIGGY_MESH` / `Config.LEGENDARIES` / `Config.LOOT_MESH` row) and, for
  the meshes, the new offset/size that must land in the SAME edit as the id.
* Afterwards the manifests are rebuilt so `assets/piggies/<tier>/<key>/manifest.json`
  records the ids the sheets just became, and the `*.open-hatch.png` /
  `*.before-closedback.*` records can be retired (`assets/piggies/README.md`).
"""
    with io.open(os.path.join(OUT, "README.md"), "w", encoding="utf-8") as fh:
        fh.write(text)


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    # Clear stale copies (never .apikey, never anything outside the two buckets).
    for bucket in ("textures", "meshes"):
        d = os.path.join(OUT, bucket)
        if os.path.isdir(d):
            shutil.rmtree(d)

    body_id, legend = read_config_mesh_ids()
    for tier in TIERS:
        tdir = os.path.join(PIGGIES, tier)
        if not os.path.isdir(tdir):
            continue
        for key in sorted(os.listdir(tdir)):
            skin_dir = os.path.join(tdir, key)
            if os.path.isfile(os.path.join(skin_dir, "manifest.json")):
                stage_skin(tier, skin_dir)
    stage_meshes(body_id, legend)

    write_csv()
    try:
        import subprocess
        ignored = subprocess.run(["git", "check-ignore", "-q", "import/"], cwd=ROOT).returncode == 0
    except Exception:
        ignored = False
    write_readme(ignored)

    c = counts()
    print(f"staged {len(rows)} rows: textures {c['textures']}, mesh files {c['meshes_files']} ({c['meshes_rows']} rows)")
    for s, n in sorted(c["by_status"].items()):
        print(f"  {s:13} {n}")
    if renamed:
        print("renamed on collision:", renamed)
    # Verify: every CSV source exists and every staged copy is byte-identical.
    bad = 0
    for r in rows:
        src = os.path.join(ROOT, r["source"])
        dest = os.path.join(OUT, "meshes" if r["role"] == "mesh" else "textures", r["upload_as"])
        if not os.path.exists(src) or not os.path.exists(dest) or sha256(src) != sha256(dest):
            print("  MISMATCH:", r["source"], "->", dest)
            bad += 1
    if problems:
        print("\nMANIFEST REFERENCES NOT ON DISK:")
        for p in sorted(set(problems)):
            print("  ", p)
    return 1 if (bad or problems) else 0


if __name__ == "__main__":
    sys.exit(main())
