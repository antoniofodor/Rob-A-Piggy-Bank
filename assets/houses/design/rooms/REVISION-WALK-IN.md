# B2 revision — real walk-in house interiors

## Latest user direction (supersedes the separate-room brief)

On September 16, after reviewing the first trophy-room concepts, the user
requested interiors that occupy the actual houses in the street. Players
walk through the front door without teleporting/leaving the world. Interior
size and condition should progress with house tier. The starter house should
feel dingy. Larger houses may contain multiple accessible floors and rooms.

The four `*-blockout.rbxmx` files, their generated geometry JSON, original
`mount-contract.json`, and the four broad trophy-room concept PNGs in this
folder describe the superseded separate-room design. They are draft studies,
not approved assets, and must NOT be integrated. Existing coplanar findings
in `geometry-report.json` were not fixed because that geometry was superseded.
The export tool `build_room_blockouts.py` is historical study tooling only.

## Proposed architecture and visual progression

Keep a real interior inside each house's structural envelope. The exterior
and interior must be authored together: a hollow shell, door opening,
walkable floor, appropriately placed opaque windows, stairs and headroom.
An invisible wall in a facade is not an entrance. Do not mount these rooms
in a reserved region or hide a teleport behind the door animation.

| Houses | Proposed accessible layout | Display treatment |
| --- | --- | --- |
| Starter Shack | One small, dingy room | Crooked timber shelf, scuffed-looking flat-colour panels, modest framed achievement board |
| Cosy Cottage / Garden Bungalow | One comfortable main room, small side nook | Cabinet and a wall of achievements |
| Brick Townhouse | Two compact floors connected by stairs; upper exterior storey can remain attic pending floorplan | Ground-floor living/showcase space, upstairs collection |
| Suburban Villa / Coastal Villa | Two floors, two or three rooms total | Living area, upstairs personal trophy room |
| Stone Manor / Hilltop Mansion / Midnight Modern | Two or three accessible floors within their actual volumes | Entrance display, achievement gallery, collection room |
| Sunset Sky Villa / Neon Tower / Skyline Penthouse | Several connected floors; choose three furnished levels initially, stair access continuous | Entrance, collection floor, upper showcase/lounge |
| Chateau / Palace / Sky Castle / Observatory | Three accessible floors initially | Grand entrance, trophy gallery, signature upper room |
| Imperial Estate / Celestial Citadel | Three or four accessible floors initially | Multiple galleries and a signature summit room |

Floor counts above are design proposals, not a new requirement that every
visible exterior storey must be a separate furnished room. The final choice
must fit each house's measured height, floor thickness, camera and stairs.
Do not fake inaccessible rooms with interactive-looking doors.

## Trophies and achievements

Reuse the same saved collection and TrophyService state in every house.
Every house offers access to the whole achievement record. The starter can
show selected objects on compact shelving; a larger home can physically show
more at once. An achievement book/board lists the rest. That book is a
proposal requiring Fable's UI/data wiring, not a new saved award system.

Retain Fable's mount names but use house-relative positions: `Featured`,
`Shelf_1..Shelf_N`, `Wall`, `Record`, `Plaque_Legacy`, `Door_Exit`.
`Door_Exit` now names the real threshold/orientation, not a teleport target.
Each house specifies its own N and floors. Mounts remain identified by name;
saved display selections refer to trophy IDs, never world coordinates.
On moving into a smaller house, keep all trophies; use a deterministic
featured/selected-first arrangement and store overflow without deleting it.

## GPT next physical-design deliverables

The first visual studies are now `starter-walk-in.png` and
`haunted-manor-walk-in.png` (exact prompts in `walk-in-prompts.json`). They establish
the condition/scale contrast, not measured floorplans. Generated plan and
cutaway views are illustrative; the staircase/landing and starter camera
clearance need to be resolved in actual geometry.

1. Starter Shack furnished cutaway and measured plan: prove dingy can be
   charming/readable without noisy textures or a cramped doorway.
2. Villa/manor two-floor cutaway: prove stair access, upper landing, camera
   clearance and separate display areas.
3. Per-house floorplans inside the actual model footprint, then interior
   geometry and named mounts. High-tier exterior concepts may need revision
   around stairs and real internal volumes before they are approved models.

## Fable integration impact

Existing House builders create cosmetic non-colliding scenery. They need
real door voids, collidable shells/floors and a visitor-safe upgrade/rebuild
path. On changing house/owner leaving, relocate occupants safely before
destroying the current structure; retain collections and progress.

Resolve the chase rule explicitly: physical doors cannot merely hide a
teleport refusal. A wanted/carrying player must not gain an invulnerable
hiding spot, and a pursuer must not get stuck outside while their target is
inside. Entry restrictions or indoor pursuit need actual server enforcement.
Keep the robbable piggy outside unless the user changes that separate rule.

Measure complete budgets per house INCLUDING interiors and displayed trophy
models. The previous ~200-part exterior budget is not a total allowance for
several fully populated floors. Furniture should use simple shared modules;
measure multi-house mobile performance before furnishing every floor.
