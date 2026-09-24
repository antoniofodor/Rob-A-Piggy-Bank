#!/usr/bin/env python3
"""Upload a skin's accessories-only FBX as a Model asset and record the receipt.

    python tools/upload_skin_accessories.py --keys rockslide          # dry run
    python tools/upload_skin_accessories.py --keys rockslide --go

RUN THIS YOURSELF, for the reason `tools/upload_images.py` says at length:
every upload lands on YOUR Roblox account and is moderated there.

WHY A MODEL AND NOT AN IMAGE. `upload_images.py` refuses meshes because the
Assets API hands back a MODEL id rather than the per-part MeshIds the game
needs, and tells you to use Studio's 3D Importer instead. That is true and it
is not the whole story: `InsertService:LoadAsset(<model id>)` loads the model
into a live session, and its MeshParts carry real `MeshId`s that can be read
straight off them -- which is what `tools/capture_mesh_ids.luau` does after a
hand import, without the hand import. Proved on the already-live hedgehog
accessories model (72540328543121 -> one MeshPart, MeshId 94226638486977).

The receipt lands in `assets/piggies/<tier>/<key>/roblox-uploads.json`, the
same file the epic-v2 pass wrote, so the two rounds read the same way.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path

import requests
import upload_images

ROOT = Path(__file__).resolve().parents[1]
PIGGIES = ROOT / "assets" / "piggies"
API = "https://apis.roblox.com/assets/v1"


def tier_of(key):
    for t in ("common", "rare", "epic", "legendary", "unreleased"):
        if (PIGGIES / t / key).is_dir():
            return t
    return None


def accessory_fbx(key):
    folder = PIGGIES / tier_of(key) / key
    hits = sorted(folder.glob("package/*-accessories.fbx"))
    return (folder, hits[0]) if hits else (folder, None)


def upload_model(session, user_id, path: Path, name: str):
    request = {
        "assetType": "Model",
        "displayName": name[:50],
        "description": "Rob a Piggy Bank skin accessory geometry",
        "creationContext": {"creator": {"userId": user_id}},
    }
    with path.open("rb") as fh:
        r = session.post(
            f"{API}/assets",
            files={
                "request": (None, json.dumps(request), "application/json"),
                "fileContent": (path.name, fh, "model/fbx"),
            },
            timeout=180,
        )
    r.raise_for_status()
    op = r.json()
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(90):
        time.sleep(2)
        p = session.get(f"{API}/operations/{op_id}", timeout=30)
        if p.ok and p.json().get("done"):
            body = p.json().get("response", {})
            aid = body.get("assetId")
            if aid:
                return str(aid), op_id, body.get("moderationResult", {}).get("moderationState", "?")
            raise RuntimeError(f"finished with no assetId: {body}")
    raise RuntimeError("operation did not finish in three minutes")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", required=True)
    ap.add_argument("--go", action="store_true")
    args = ap.parse_args()

    keys = [k.strip() for k in args.keys.split(",") if k.strip()]
    todo = []
    for key in keys:
        if not tier_of(key):
            sys.exit(f"{key}: no folder under assets/piggies/*/")
        folder, fbx = accessory_fbx(key)
        if not fbx:
            sys.exit(f"{key}: no *-accessories.fbx in {folder / 'package'}")
        rec_path = folder / "roblox-uploads.json"
        rec = json.loads(rec_path.read_text(encoding="utf-8")) if rec_path.exists() else {}
        digest = hashlib.sha256(fbx.read_bytes()).hexdigest()
        live = (rec.get("assets", {}).get("accessories") or {})
        if live.get("sha256") == digest and live.get("assetId"):
            print(f"  {key:12} already uploaded from these exact bytes ({live['assetId']}) -- skipping")
            continue
        todo.append((key, folder, fbx, digest, rec_path, rec))
        print(f"  {key:12} {fbx.name}  {fbx.stat().st_size // 1024} KiB")

    print(f"\n{len(todo)} model(s) to upload" + ("" if args.go else " (dry run; add --go)"))
    if not args.go or not todo:
        return

    session = requests.Session()
    session.headers["x-api-key"] = upload_images.read_key()
    import csv as csvmod
    with (ROOT / "import" / "asset-ids.csv").open(newline="", encoding="utf-8") as fh:
        rows = list(csvmod.DictReader(fh))
    user_id = upload_images.creator_id(session, rows)
    print(f"creator userId {user_id}")

    for key, folder, fbx, digest, rec_path, rec in todo:
        try:
            aid, op_id, state = upload_model(session, user_id, fbx, f"{key}-accessories")
        except Exception as exc:
            print(f"  {key:12} FAILED: {exc}")
            continue
        rec.setdefault("skin", key)
        rec.setdefault("revision", "og-redesign-v1")
        rec["creatorUserId"] = user_id
        rec.setdefault("assets", {})["accessories"] = {
            "source": str(fbx.relative_to(ROOT)).replace("\\", "/"),
            "sha256": digest,
            "assetType": "Model",
            "operationId": op_id,
            "assetId": aid,
            "moderationState": state,
        }
        rec_path.write_text(json.dumps(rec, indent=2) + "\n", encoding="utf-8")
        print(f"  {key:12} -> {aid}  ({state})")
    print("\nNow read the per-part MeshIds off each model with InsertService:LoadAsset.")


if __name__ == "__main__":
    main()
