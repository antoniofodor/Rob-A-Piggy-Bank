#!/usr/bin/env python3
"""Upload the staged skin sheets through Open Cloud and write every id back.

    python tools/upload_images.py            # dry run: says what it WOULD send
    python tools/upload_images.py --go       # uploads, writes ids into the CSV
    python tools/upload_images.py --go --only re-upload   # or --only new

RUN THIS YOURSELF. Every upload lands on YOUR Roblox account and is moderated
there (CLAUDE.md records a moderation strike from generated uploads), so this
is deliberately a script the designer runs by hand, never a tool a session
calls. It reads the API key from `import/.apikey` (or `ROBLOX_API_KEY`) and
prints no part of it.

WHY THIS EXISTS. Studio's Asset Manager uploads a folder of images in one
multi-select and then shows their ids one at a time, and the Assets API has
NO list endpoint. (A hand upload's id CAN be recovered afterwards -- the Studio
MCP's inventory search plus GetProductInfo for the date, see CLAUDE.md -- but
it is a per-name hunt through every earlier copy.) Uploading through the API
instead returns
each id in the response, so this writes them into `import/asset-ids.csv`
`current_asset_id` as they arrive, one row at a time, and the CSV is the
hand-off to whoever owns Config.luau and the SurfacePacks files.

UPLOAD ONCE, BY ONE ROUTE. The 2026-09-18 batch was uploaded twice -- by hand
and then again here to capture ids -- and the first copy is dead weight on the
account that cannot be archived (Image is not an archivable type). So: if you
already uploaded a file in Studio, paste its id into the CSV by hand and this
script will skip the row; it never sends a row that already carries an id
unless the row's status is `re-upload` AND you pass `--force`.

WHAT IT SENDS: only rows with status `re-upload` or `new` whose `upload_as`
is a PNG. Meshes (FBX/OBJ) are not sent -- the Assets API's Model type does
not hand back the per-part MeshIds the game needs; import those with the 3D
Importer and run tools/capture_mesh_ids.luau in the command bar instead.

The creator userId is read off any `already-live` asset in the CSV via the
Get Asset endpoint, so nothing has to be typed.
"""
import argparse
import csv
import json
import os
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

ROOT = Path(__file__).resolve().parents[1]
CSV = ROOT / "import" / "asset-ids.csv"
KEYFILE = ROOT / "import" / ".apikey"
API = "https://apis.roblox.com/assets/v1"


def read_key() -> str:
    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if key:
        return key
    if not KEYFILE.exists():
        sys.exit("no ROBLOX_API_KEY and no import/.apikey")
    text = KEYFILE.read_text(encoding="utf-8").strip()
    # Either a bare key, or JSON with the key under a conventional name.
    try:
        data = json.loads(text)
        for name in ("apiKey", "api_key", "key", "x-api-key", "token"):
            if isinstance(data, dict) and data.get(name):
                return str(data[name]).strip()
    except ValueError:
        pass
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            if "=" in line and " " not in line.split("=", 1)[0]:
                line = line.split("=", 1)[1].strip().strip('"')
            return line
    sys.exit("could not find a key in import/.apikey")


def creator_id(session: requests.Session, rows: list) -> str:
    for row in rows:
        aid = row["current_asset_id"].replace("rbxassetid://", "").strip()
        if aid.isdigit():
            r = session.get(f"{API}/assets/{aid}", timeout=30)
            if r.ok:
                ctx = r.json().get("creationContext", {}).get("creator", {})
                uid = ctx.get("userId")
                if uid:
                    return str(uid)
    sys.exit("could not read the creator userId off any live asset; pass --user-id")


def upload(session: requests.Session, user_id: str, path: Path, name: str) -> str:
    request = {
        "assetType": "Image",
        "displayName": name[:50],
        "description": "Rob a Piggy Bank skin sheet",
        "creationContext": {"creator": {"userId": user_id}},
    }
    with path.open("rb") as fh:
        r = session.post(
            f"{API}/assets",
            files={
                "request": (None, json.dumps(request), "application/json"),
                "fileContent": (path.name, fh, "image/png"),
            },
            timeout=120,
        )
    if r.status_code == 429:
        raise RuntimeError("rate limited")
    r.raise_for_status()
    op = r.json()
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    # Poll the operation until the asset exists. Moderation runs AFTER this;
    # the id is real either way.
    for _ in range(60):
        time.sleep(2)
        p = session.get(f"{API}/operations/{op_id}", timeout=30)
        if p.ok and p.json().get("done"):
            body = p.json().get("response", {})
            aid = body.get("assetId")
            if aid:
                state = body.get("moderationResult", {}).get("moderationState", "?")
                return f"{aid}|{state}"
            raise RuntimeError(f"operation finished with no assetId: {body}")
    raise RuntimeError("operation did not finish in two minutes")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--go", action="store_true", help="actually upload (default is a dry run)")
    ap.add_argument("--only", choices=["re-upload", "new"], help="restrict to one status")
    ap.add_argument("--force", action="store_true", help="re-send re-upload rows that already carry an id")
    ap.add_argument("--user-id", help="creator userId, if it cannot be read off a live asset")
    ap.add_argument("--include-unreleased", action="store_true",
                    help="also send rows flagged UNRELEASED/UNWIRED (skins nothing in the game reads yet)")
    ap.add_argument("--keys",
                    help="comma-separated skin keys; send only these rows. A round is usually "
                         "ONE batch of skins rather than one status, and --only/--include-unreleased "
                         "cannot say that: every sheet of a skin with no pack yet reads UNWIRED, so "
                         "the flag that lets a new batch through also lets every unreleased coat "
                         "through with it. Name the batch instead.")
    args = ap.parse_args()

    with CSV.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        fields = reader.fieldnames
        rows = list(reader)

    keys = None
    if args.keys:
        keys = {k.strip() for k in args.keys.split(",") if k.strip()}
        known = {r["skin"] for r in rows}
        unknown = keys - known
        if unknown:
            sys.exit(f"no rows for key(s): {', '.join(sorted(unknown))}")

    todo = []
    for row in rows:
        if not row["upload_as"].lower().endswith(".png"):
            continue
        if keys is not None and row["skin"] not in keys:
            continue
        if row["status"] not in ("re-upload", "new"):
            continue
        if args.only and row["status"] != args.only:
            continue
        flagged = ("UNRELEASED" in row["assign_to"]) or ("UNWIRED" in row["assign_to"])
        if flagged and not args.include_unreleased:
            continue  # nothing in the game reads these yet; do not spend a moderation on them
        has_id = row["current_asset_id"].strip() != ""
        if row["status"] == "new" and has_id:
            continue  # pasted in by hand already
        if row["status"] == "re-upload" and has_id and not args.force:
            # A re-upload row keeps the OLD id in the CSV so you can see what
            # is live; it still needs the new bytes sent. --force says so.
            pass
        src = ROOT / row["source"]
        if not src.exists():
            print(f"MISSING {row['source']}", file=sys.stderr)
            continue
        todo.append((row, src))

    print(f"{len(todo)} image(s) to upload"
          + ("" if args.go else " (dry run; add --go)"))
    for row, src in todo:
        print(f"  {row['status']:9} {row['upload_as']:44} <- {row['source']}")
    if not args.go or not todo:
        return
    if any(r["status"] == "re-upload" for r, _ in todo) and not args.force:
        print("\nre-upload rows carry their OLD id; this sends new bytes and REPLACES the id.")
        print("Re-run with --force to confirm, or --only new to skip them.")
        return

    session = requests.Session()
    session.headers["x-api-key"] = read_key()
    user_id = args.user_id or creator_id(session, rows)
    print(f"creator userId {user_id}")

    def save() -> None:
        tmp = CSV.with_suffix(".csv.writing")
        with tmp.open("w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=fields)
            w.writeheader()
            w.writerows(rows)
        os.replace(tmp, CSV)

    done = 0
    for row, src in todo:
        name = Path(row["upload_as"]).stem
        for attempt in range(5):
            try:
                result = upload(session, user_id, src, name)
                break
            except RuntimeError as err:
                if "rate limited" in str(err) and attempt < 4:
                    wait = 15 * (attempt + 1)
                    print(f"  rate limited, waiting {wait}s")
                    time.sleep(wait)
                    continue
                print(f"FAILED {row['upload_as']}: {err}", file=sys.stderr)
                result = None
                break
            except requests.HTTPError as err:
                print(f"FAILED {row['upload_as']}: {err} {err.response.text[:200]}", file=sys.stderr)
                result = None
                break
        if not result:
            continue
        aid, state = result.split("|", 1)
        row["current_asset_id"] = f"rbxassetid://{aid}"
        row["status"] = "uploaded"
        done += 1
        save()  # after EVERY row, so a crash never loses an id
        print(f"  {row['upload_as']:44} -> {aid}  ({state})")
        time.sleep(1)
    print(f"\n{done}/{len(todo)} uploaded; ids written to {CSV.relative_to(ROOT)}")
    print("Hand the CSV to the session that owns Config.luau and the SurfacePacks files.")


if __name__ == "__main__":
    main()
