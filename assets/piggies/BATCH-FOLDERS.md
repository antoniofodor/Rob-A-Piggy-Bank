# The batch folders at the top of `assets/piggies/`

`README.md` beside this file describes `<tier>/<key>/` -- one folder per skin, five rooms
under each, and it is the source of truth for a piggy. It does not describe the twelve
other folders at this level, which is how a cleanup pass came close to deleting three
that the game reads. **This file is that map.** Nothing here is a skin; every one is a
BATCH -- one session's work across many skins at once.

**The rule that matters: a folder named `-v<N>` is not stale because of the suffix.**
Read the row before touching it. Two of these are named in `src/` by path, and a third
is the authoring source of a generated Luau file.

## Live -- something in `src/` reads this, or is generated from it

| folder | size | why it is live |
| --- | --- | --- |
| `og-redesign-v1/` | 18 MB | **Named in `Config.luau`** (the OG redesign block): *"Fifteen of these came out of `assets/piggies/og-redesign-v1/` in one batch, plus `muddy`."* Fifteen live `Config.SKINS` coats were baked here. |
| `og-refresh-v2/` | 20 MB | **Named in `src/ReplicatedStorage/Shared/SpectralScanData.luau` line 1**: *"Actual mesh cross sections, sampled by og-refresh-v2/extract_scan.py."* That Luau file is live game data and this folder holds the script that produced it. Also installed Ghost and Hologram (both live keys). |
| `arcade-build-v1/` | 15 MB | The **builder for ten live skins** -- `playerone retrocarpet respawn jackpot pixel circuitboard powerup synthwave finalboss mechaplayer`, every one a `Config.SKINS` row. Its own README gives the rebuild command (`prepare_builder.py`, `build_batch.py --keys ...`, `finalize.py`). Its authored six-second motion is what `src/ReplicatedStorage/Shared/ArcadeMotionData.luau` was sampled from. Also holds 185 uploaded mesh ids recorded nowhere else -- see `ORPHANED-UPLOAD-IDS.md`. |
| `approved-imports-20260923/` | 19 MB | The **upload receipts** for eight live skins' `og-v2` sheets (`aurora banker finalboss jackpot mechaplayer neonmint quartz rockslide`). Each `<skin>/roblox-uploads.json` pairs an `assetId` with the `sha256` of the file it was uploaded from, under `<tier>/<skin>/revisions/og-v2/sheets/`. Ids cannot be re-derived: keep. |

## Provenance -- the record of how a live skin got its look

Concept art and per-asset revision studies. Nothing reads them; they are why a shipped
skin looks the way it does, and they are small.

| folder | size | what it is |
| --- | --- | --- |
| `arcade-concepts-v1/` | 20 MB | The `image_gen` concepts for the arcade collection, with the **exact prompts and receipts** (`prompts.json`, `expansion-prompts.json`, and their `*-receipts.json`). The finished models are in `arcade-build-v1/`. |
| `arcade-legendary-v2/` | 96 KB | **The installed geometry revision.** `arcade-mecha-v4` and `arcade-overdrive-v3` both say in as many words that v2 is what is installed. |
| `arcade-jackpot-v3/` | 76 KB | Jackpot revision 3 -- shades and payout chutes, starting from the v2 model. |
| `arcade-mecha-v3/` | 44 KB | Mecha Player review revision 3 -- the closed crown shell. |
| `arcade-mecha-v4/` | 54 KB | Mecha Player review 4. Its README: *"Local review only. The installed game revision remains v2."* |
| `arcade-overdrive-v3/` | 69 KB | The renaming of Final Boss to **Overdrive**, later overruled. *"v2 geometry remains installed."* |
| `arcade-mage-v4/` | 44 KB | The renaming of the same skin to **Spellcaster**, which is what shipped -- `Config.SKINS.finalboss.name` is `"Spellcaster"` today, with the `finalboss` key kept so saves and uploaded ids still resolve. |
| `arcade-spellcaster-v5/` | 48 KB | The latest of that chain: the hood added to the accepted v4 model. |
| `epic/_concepts-v2/` | 2.3 MB | Sits under `epic/` but is **not a key** -- the approved four-skin concept for the animal epics (Hedgehog, Lion, Storm Stone, Peacock). Two of those four are gone now (`lion` and `stormstone`), so this is the record of a decision, not of a current skin. |

**Read the rename chain in order** -- `arcade-legendary-v2` (installed) then `-overdrive-v3`
then `-mage-v4` then `-spellcaster-v5` -- or the display name in `Config` looks like it
disagrees with the folder that produced it. It does not; the key never moved.

## The one retired key still on disk

`epic/stormstone/` is **not** in `Config.SKINS` -- the skin is Stormcaller, and Storm
Stone was retired on 2026-09-23. It is kept deliberately, and `Config.luau` says so in
the OG redesign block: *"Its sheets are live on the account and its art is still under
assets/piggies/epic/stormstone/ -- nothing here reads either."* Deleting the folder would
make that comment false, so retire the comment in the same change or leave both.

Its three uploaded ids are in `epic/stormstone/roblox-uploads.json`, which is untracked
and is the only copy -- its own `manifest.json` has an empty `idSources`.

## What is safe to remove at this level

Nothing, on the evidence above. What IS removable is the generated output scattered
through the per-key folders, which `.gitignore` already calls output: `__pycache__/`,
Blender's `*.blend1` rolling backups, and `preview/*_view.blend`, which
`make/make_view_blend.py` rewrites on every render. That is about 33 MB across both
`assets/piggies` and `assets/houses` and all of it rebuilds itself.
