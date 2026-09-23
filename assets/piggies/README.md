# `assets/piggies/` -- one folder per piggy skin, and the source of truth for it

Designer decision, 2026-09-22: *"the piggies should all live in a folder under
`assets/piggies/` in the codebase, including a folder for the generation of the
texture and images of the preview of the skin etc, organised per folder per
piggy, so that will be the source of truth and I can later clean up the rest."*

This folder is that. Everything a skin IS -- its authored scene, the generator
that builds it, the sheets that get uploaded, the pictures of it, the derived
import package built from all of that, and a record of which Roblox ids those
sheets became -- lives under `<key>/`, named after the skin's `Config.SKINS`
key, under the folder of its TIER, and nowhere else is authoritative. All 29
keys are here: the 24 coats moved in the morning, then `dragon`, `phoenix`,
`rainbowtiger`, `stormwolf` and the shared `metal/` pack once the legendary
rebuild finished, and the whole set was sorted by tier the same evening.

```
assets/piggies/common/      bee cow giraffe ladybird leopard snowleopard tiger zebra
assets/piggies/rare/        bubblegumleopard cookiescream glacier honeycomb magma
                            peppermint strawberrycow watermelon
assets/piggies/epic/        lion stormstone
assets/piggies/legendary/   diamond dragon phoenix rainbowtiger stormwolf
assets/piggies/unreleased/  koi patched piggybank raptor spotty   (no Config.SKINS row yet)
                            metal                                 (a shared pack, not a skin)
```

**The tier is `Config.SKINS.<key>.rarity` on the day of the sort, and from
then on it is THE FOLDER.** `blender/pig/paths.py` finds a key by searching
the tier folders and reports the tier it found it in; nothing in the toolkit
reads Luau to know where a piggy is, so a folder moved between tiers by hand
is simply found in its new one, and a key that exists nowhere is born under
`unreleased/`, which is what a coat with no row is. Each `manifest.json`
records whether its folder still matches the rarity in Config.

## The layout

```
assets/piggies/
  README.md                       this file
  .gitignore                      the rolling backups and the rewritten preview scene
  <tier>/<key>/
    manifest.json                 WHAT THIS SKIN IS: key, Config.SKINS row (name, rarity,
                                  scale, surface / legendary), its SURFACE_PACKS row or the
                                  legend_* packs Config.LEGENDARIES names, the SurfacePacks
                                  model.json paths in src/, the asset ids those carry TODAY,
                                  and which file here each id was uploaded from (sha256).
                                  Rebuilt by a script from those files; never typed.
    source/
      <key>.blend                 the authored scene: the master pig carrying this skin's
                                  materials. What the generator WRITES and what you open.
      <key>_closed.blend          the same scene with the vault hatch filled
                                  (make/closedback_fill.py). Same UVs plus the fill's island.
      <key>.before-closedback.blend   (dragon, phoenix) the OPEN scene the legendary rebuild
                                  started from; for those two <key>.blend is already closed
      coat-spec.json              a rare coat's palette + parent-scene hash
                                  (make/build_rare_coat.py). Not every skin has one.
    generate/
      make_<key>_blend.py         the generator, and every number that decides the coat.
                                  A full procedural graph for the base animals; a six-line
                                  stub calling make/build_rare_coat.py for a rare recolour.
      (diamond: make_diamond.py + preview_diamond.py -- it bakes from the master directly)
      (phoenix: build_phoenix_asset.py, loop.sh, measure.py, preview_anim.py, strip.py,
       validate_phoenix.py, render_phoenix_preview.py, and concepts-v2/ -- the concept set)
      (rainbowtiger: beard-shape-study/ and rainbow-tiger-concept/ -- inputs the builder reads)
      (stormwolf: look_stormwolf.py, preview_anim.py; meshy-source/ is where the Meshy
       download goes when it is re-fetched)
    sheets/
      <key>_body_color.png        THE CURRENT BODY SHEET -- the closed-back re-bake
      <key>_trim_color.png        the trim sheet (unchanged by the hatch; one copy)
      <key>_body_color.open-hatch.png
                                  the sheet the LIVE ColorMap id was uploaded from. Kept
                                  beside the current one and written by nothing.
      <key>_body_color.before-closedback.png
                                  (dragon, phoenix) the same record under the rebuild's name
      <key>_<group>_alpha.png     animated-skin masks (magma, stormstone, the legendaries)
      diamond_<group>_{normal,roughness}.png   the diamond's facet pack
      pig_metal_*.png, pig_value_ladder.png    (metal) the shared band overlay pack
    preview/
      <key>_hatch.png, <key>_hero.png   closed-back renders (make/closedback_render.py);
                                        the legendaries also carry <key>_legendary_*.png
      <key>_shop-card.png / .json       a copy of the crate card, with its upload id
      <key>_view.blend                  the game-lit preview scene (make/make_view_blend.py);
                                        rewritten on every render, so gitignored
    package/
      <key>-complete.blend / .fbx       the DERIVED import package: assembled scene, FBX, the
      <key>-{hero,front,crown,spine}.png   studio renders, <key>-asset-report.json, README.md,
      shop-cards/<key>.png (+.json)     index.html; for a legendary also the idle FBX/GIF,
      *.before-closedback.*             motion/ frames, the helper .luau, and the rebuild's
                                        backups. OUTPUT of make/package_animal.py or the
                                        legendary builders -- never edited by hand.
```

**Five rooms under a tier, and what decides which room a file is in is who
writes it.**
`source/` is what a person opens; `generate/` is what a person runs (and what
it reads: studies, concepts, downloads); `sheets/` is what gets uploaded;
`preview/` is what gets looked at; `package/` is what a builder derived from
the other four for import. A file that fits two rooms goes in the one nearer
the upload.

## What "current" means in `sheets/`, and why there are two body sheets

The closed-back pass of 2026-09-22 (`blender/pig/renders/closed-back-test/README.md`)
fills the vault hatch in the body mesh and re-bakes every body sheet against
it. The designer's call is that those re-bakes are the current truth, so
`<key>_body_color.png` here IS the closed-back sheet. Nothing has been uploaded
yet: every live `ColorMap` id in `src/ReplicatedStorage/Shared/SurfacePacks/`
still points at the sheet baked on the OPEN body, which is kept as
`<key>_body_color.open-hatch.png` so the id has a file to be checked against
(`manifest.json` carries both sha256s). The day the closed sheets are uploaded,
the `.open-hatch.png` files are the ones to retire.

The legendary rebuild closed `dragon` and `phoenix` itself and left its own
backups: there, `<key>.blend` and `<key>_body_color.png` are already the closed
versions and the `*.before-closedback.*` files beside them are the open-hatch
record. `rainbowtiger`'s coat sheet went through the same rule as the commons.
`stormwolf` has its own Meshy body, which the fill does not target; the
designer handles it by hand, and nothing about it was regenerated here.

Trim sheets did not change (the fill never touches the trim mesh), so there is
one trim sheet. The diamond's trim normal/roughness maps came out of the pass
byte-identical and are kept once; its body maps did change and carry the pair.

**`make/bake_skin.py` opens the CLOSED scene when the skin has one**
(`paths.skin_bake_blend`), so re-baking a skin reproduces the current sheet
rather than overwriting it with an open-hatch one. The generators still write
the OPEN `<key>.blend`, because the master `pig/pig_parts.blend` is still open;
the day the master is filled the two files collapse into one and nothing here
has to change.

## How the scripts find this folder

`blender/pig/paths.py` is the ONLY place that knows this layout. Every script
resolves a skin through it -- `skin_blend`, `skin_closed_blend`,
`skin_bake_blend`, `skin_script`, `coat_spec`, `skin_map`,
`skin_open_hatch_map`, `skin_alpha`, `skin_emissive`, `sheet`, `skin_view`,
`skin_preview`, `skin_study`, `skin_package_dir` / `animal_package`,
`tier_of`, `tier_gallery`, `manifest`, `skin_keys` -- and `paths.find` also
searches every room under every tier, so `--blend tiger.blend` on a command
line still resolves. The
toolkit itself (`paths.py`, `skin_colours.py`, `skin_parts.py`, `rosette.py`,
`png_write.py`, `rare_coats.py`, `make/*.py`, `look/*.py`, `masks/*.py`, the
master scene and the `.obj` exports under `blender/pig/pig/`) stays in
`blender/pig/`: it is shared by every skin and belongs to none of them.

A generator in `generate/` bootstraps by walking UP from its own location until
it finds either `paths.py` or a folder holding `blender/pig/paths.py`, then puts
`blender/pig/` on `sys.path`. So run one from anywhere:

    blender --background --python assets/piggies/common/tiger/generate/make_tiger_blend.py
    blender --background --python blender/pig/make/bake_skin.py       -- --skin tiger
    blender --background --python blender/pig/make/make_view_blend.py -- --skin tiger --render
    blender --background --python blender/pig/make/package_animal.py  -- --skin tiger

The method is unchanged and is still `blender/pig/WORKFLOW.md`.

## The tier galleries stayed where they were

`assets/skins/animal/{index.html,manifest.json,README.md}` and the per-tier
`common/`, `rare/`, `legendary/` index pages are what the gallery builders
(`make/build_animal_gallery.py`, `build_rare_gallery.py`, `build_*_gallery.py`)
write, and they now link into `package/` here. They are indexes of a tier, not
of a piggy, which is why they did not move. The old package folders under
those tiers hold only the designer's copies to clean up (see below).

## Readers of the package, all repointed

`blender/shop/render_skin_images.py` (the crate cards, which glob the tier
folders for a key),
`tools/stage_animal_import.py` (the Studio import staging),
`make/verify_animal_packages.py`, the gallery builders, every legendary builder
and renderer under `make/`, and the two upload registers
(`assets/shop-ui/skin-images/manifest.json`, each package's
`shop-cards/<key>.json`) all read `assets/piggies/<tier>/<key>/package/` now, through
`paths.animal_package(key)` where the script imports the toolkit and by
globbing the tier folders where it does not.

## Skins with no game row yet

`koi`, `patched`, `piggybank`, `raptor` and `spotty` are authored rare coats
(`blender/pig/rare_coats.py`, `docs/PIGGY-SKIN-MAP.md`) with no `Config.SKINS`
row, so nothing in the game reads their sheets. They live here like every other
skin; their manifests say so. `magma` and `stormstone` have rows that still
carry a code-built pattern/anim rather than a `surface`, so their sheets are
baked but not wired. `metal` is not a skin key at all: it is the band-overlay
pack `Config.SKINS.bullion` wears through `SURFACE_PACKS.bands`, which is why it
sits under `unreleased/` despite being live -- it has no rarity to sort by.

## The dragon's painted bake is LEGACY

`legendary/dragon/` carries two dragons. `package/` is the LIVE one: the
raised-scale build (`Config.LEGENDARIES.dragon`, 24 parts) whose maps were
uploaded from `package/dragon_*_color.png` and `package/dragon_*_emissive.png`.
`source/dragon.blend`, `sheets/dragon_body_color.png` (and its trim, alpha and
`.before-closedback` companions) and `preview/dragon_hatch|hero.png` are the
PAINTED molten-scale coat `generate/make_dragon_blend.py` bakes onto the plain
pig -- nothing in the game reads them. They stay as the record of the coat
`make/make_dragon_kit.py` previews with; the manifest lists them under
`legacy`.

## Adding a skin

1. Copy a generator into `assets/piggies/<tier>/<key>/generate/make_<key>_blend.py`
   (or a stub plus a `rare_coats.py` entry). `paths.skin_dir("<key>")` makes the
   folder; the rooms appear on first use.
2. Run the loop above. The bake lands in `sheets/`, the preview in `preview/`,
   the package in `package/`.
3. Upload the two sheets once, put the ids in two `model.json` files under
   `src/ReplicatedStorage/Shared/SurfacePacks/`, add the `SURFACE_PACKS` row and
   `surface =` on the skin (`WORKFLOW.md`, "Getting it into the game").
4. Rebuild the manifests so the folder records the ids it just became.

## git

A skin's scene (`source/*.blend`), its sheets and its package are committed
here on purpose: this folder is the source of truth, and the argument
`blender/.gitignore` makes for not carrying regenerable blends was about a
folder that was NOT the source of truth. The root `.gitignore` un-ignores
`assets/piggies/**/*.fbx` and `*.glb` for the packages, exactly as it did for
the old tier folders. What is ignored is only what is rewritten on every run --
`preview/*_view.blend` and Blender's `*.blend1` backups.

## What the designer can delete once happy (nothing here was deleted by the move)

* `assets/piggies/<key>/` no longer exists (the sort by tier `git mv`ed whole
  folders), so there is nothing to clean up from the flat layout.
* `blender/pig/skins/<key>/` for all 29 keys: the untracked copies left behind
  (`*.blend`, `*_view.blend`, `*_color.png`, the legendaries' `.before-closedback`
  backups). The tracked files already left via `git mv`; only `README.md` needs
  to stay.
* `assets/skins/animal/<tier>/<key>/` for all 20 packages: the untracked copies
  (`lion/` entirely; the legendaries' regenerated files and backups). Keep the
  tier-level `index.html` / `manifest.json` / `README.md` files.
* `blender/pig/renders/closed-back-test/full/<key>/` -- the pass's scratch
  copies (gitignored anyway).
* Once the closed sheets are uploaded and the model.json ids updated: every
  `sheets/*.open-hatch.png` and the legendaries' `*.before-closedback.*`.
