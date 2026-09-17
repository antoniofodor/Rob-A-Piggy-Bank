# Phase 4b visual handoff — September 16

**Latest package:** `fantasy-v3/index.html` contains the six revised concepts
and animated Portal House timing study. Legendary house animations are
now explicitly requested. The first Blender asset is at
`assets/houses/models/mushroom-v1/`; Studio integration remains pending.
The v2 notes below are historical where revision 3 supersedes them.

**Current fantasy revision:** open `fantasy-v2/index.html`. Fable's fantasy
brief replaces the nine realistic additions; the user subsequently reserved
gingerbread for seasonal content and requested an all-black replacement and
greener slime walls. The old shop demo's nine new IDs must not be integrated.
Its UI states/layout still apply. See `fantasy-v2/HANDOFF.md`.

Open `index.html` for the visual gallery and `ui/catalogue.html` for the
interactive house-shop prototype. These are local review artifacts; they
are not connected to Roblox or to real purchases.

## Latest direction

The user has replaced the separate trophy-room idea with real, walk-in
interiors inside the street houses. Size, condition, rooms and accessible
floors should progress with the house. The starter is small and dingy.
Larger houses can contain stair-connected floors and dedicated galleries.
See `rooms/REVISION-WALK-IN.md` before implementing B2 or finalising B3.

## Deliverables and status

| Brief | Ready for visual review | Still to do |
| --- | --- | --- |
| B1 / 4b.3 | Interactive 18-house catalogue; five states; price sort; All/Owned/Affordable filters; responsive geometry; `ui/HANDOFF.md` | Fable's native UI/data wiring; actual model previews; complete Home-page scroll and touch QA |
| B2 / 4b.5 | Starter and manor walk-in cutaways; size/floor progression proposal; revised mount approach | Measured per-house floorplans, avatar/camera clearance, final geometry, mount placement and Fable's runtime integration |
| B3 / 4b.4 | Nine exterior concept sheets; dimensions/palettes/build route in `houses/HANDOFF.md` | Fit exteriors to walk-in floorplans, final model geometry, measured part counts/bounds and pavement/mobile review |

Generated images are design references, not measured geometry. Image labels
are not verification. In particular the manor illustration combines
inexact cutaway and plan views: a model must resolve a continuous stair
opening, landing and headroom. The starter's 16 x 12 label is a target clear
interior, pending measurement against the current shell and Roblox camera.

The original four separate-room PNGs, blockouts, geometry reports and
`build_room_blockouts.py` are superseded studies. Do not integrate their
exports. Their known coplanar findings remain documented. They are kept
only to preserve the design history; the gallery presents the new studies.

## Data and ownership

`houses/catalogue-design.json` is proposal data, not runtime configuration.
`storeys` counts the proposed visible exterior levels, not furnished floors.
`interiorMood` is a finish family only, not a room-template mapping.
Prices/IDs must be reconciled with Fable's final catalogue before wiring.
The UI demo's capacity and coins are sample values, not a claim about the
current live economy.

GPT owns visual design/assets; Fable owns gameplay, migrations, server
authority and runtime Luau integration. This package changes no runtime
source. Shared progress/master-plan files were left to the concurrent work.

## Verification

Browser reports and screenshots are in `review/`. Four sizes cover a
1040px-tall desktop, the required 546px landscape phone, an additional
361px landscape stress test and a 390px-wide portrait view. Browser checks
cover labels, images, overflow and local demo interactions. Native Studio
fonts, viewport framing, complete Home-page height and touch testing remain
pending. The shortest stress test exceeds three house-list screens; the
required 546px view remains below two. These figures exclude other Home
sections.

Rebuild prototype: `python assets/design/phase-4b/build_preview.py`.
Rebuild gallery: `python assets/design/phase-4b/build_gallery.py`.
Review script: `node assets/design/phase-4b/review/render.cjs`
(uses the installed local Playwright runtime and Edge).
