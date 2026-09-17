# House concepts — Fable revision 2 visual response

Source: `docs/HOUSE-TIER-BRIEF.md` revision 2, read September 16.
This folder is a new concept pass. It changes no runtime Luau, prices,
ownership, Studio instances or shared planning documents.

The user subsequently authorised starting physical models. A first Blender
Toadstool prototype is now at `assets/houses/models/mushroom-v1/`, with FBX,
OBJ, primitive collision/mount RBXMX, renders and measured reports. Its own
README states import/scale/camera checks still required; it is not integrated.

Concept QA notes: the generated Portal House sheet depicts its palette split
side-to-side, while this handoff proposes a front-to-back split with the ring
across the hallway. Resolve that orientation in the floorplan before modelling.
Its upper warm window should become unlit in the final exterior. The Fishbowl
sheet's small loft/ladder is illustrative, not an additional approved floor;
use `modern-readable.png` for the clean presentation. All six images remain
concept references; the numeric bounds and actual geometry must be measured.

## Current design decisions

- `portal` / Portal House replaces `dragon` at 300M.
- `thundercloud` / Thundercloud Fortress replaces `skyisland` at 600M.
- `void` / The Void is the sole black house at 1B. The Raven's Rest proposal
  is superseded; its ID must not enter the permanent registry.
- `villa` / Fairy Lantern Cottage, `modern` / Fishbowl House and `palace` /
  Ice Palace are visual re-theme proposals using existing IDs and prices.
  Their concept art does not replace live owned models.
- `goldenpig` is an earned completion-house proposal, not a 1B purchase.
  Fable owns confirmation, grant conditions and persistence. Do not insert
  a zero-cost purchasable row as a substitute for earned status.
- Keep the user's all-green Gloop House direction from fantasy-v2.
- Keep physical walk-in interiors, variable by house, as explicitly requested.

## Conflicts carried forward explicitly

**Gingerbread remains seasonal.** The latest document restores `candy` at
8M, contradicting the user's explicit seasonal-only instruction. This pass
does not generate or restore a permanent gingerbread house. The 8M slot is
unresolved: Raven's Rest also cannot occupy it under the new one-black-house
direction. This does not block the six concept sheets here. Do not finalise
the completion-house requirement against an unresolved purchase list.

**Interiors remain inside the houses.** The shared/reserved-region room
paragraphs in the brief are older than the user's walk-in instruction.
Room-family names here refer to finishes and trophy arrangements. They are
not teleport destinations. A portal-shaped door still leads through a real
opening; aquarium inhabitants stand on a dry floor; cloud access is fixed.

**Visual selection is not a gameplay rollout.** The brief itself marks the
three re-themes and earned Golden Piggy pending designer confirmation.
The user authorised getting started on the new designs; these six concepts
are a concrete visual review package, not an ownership migration or grant.

## Six deliverables

| ID | Price | Target complete W × D × H | Accessible floors | Main physical requirement |
| --- | ---: | --- | ---: | --- |
| villa | 400K | 32 × 26 × 16 | 1 | Lantern string clears entrance and headroom |
| modern | 5M | 40 × 36 × 22 | 1 | Dry entrance sleeve connects ground to dry pod |
| palace | 40M | 49 × 36 × 38 | 2 | Broad stairs and gallery fit behind colonnade |
| portal | 300M | 46 × 42 × 40 | 2 | Ring is open air; fixed hallway continues through it |
| thundercloud | 600M | 52 × 46 × 55 | 3 | Permanent ground access and fixed interior floorplates |
| void | 1B | 56 × 48 × 60 | 3 | All ring/orbit decoration fits envelope and clears paths |

All dimensions/floor counts are proposals, not measurements. Height targets
follow the brief except Ice Palace, whose exact existing geometry must be
checked before choosing final height. The scale-study SVG compares these
numeric envelopes exactly at one drawing scale; it is not a model or a
silhouette approval. No generated image is evidence of part counts or fit.

## Exterior / interior design notes

### Fairy Lantern Cottage — villa

Cream and moss-green crooked shell, round green entry, low bowed roof,
toadstool window hoods and a few deep-colour lanterns. The crooked exterior
must surround a level interior with adequate door clearance. Cozy single
room, cabinet, feature trophy niche, record book. Drive: pale stepping
stones with a moss-green border. Blurb: "A little crooked. A little magic."

### Fishbowl House — modern

A pale dry pod inside a decorative teal aquarium shell. The outer dome and
the enclosed pod are separate geometry; transparent surfaces must not sit
on each other. A dry sleeve crosses the water annulus at ground level.
Keep the pod and doorway readable from the street and shop card. Proposed
aquarium finishes build on modern display cases; no swimming mechanic is
implied. Drive: sand-coloured slabs with coral outside the route. Blurb:
"An ocean view from every wall."

### Ice Palace — palace

Wide colonnade and two frosted turrets; pale ice-blue structure with deep
cobalt accent insets. Do not build the entire palace from translucent
overlapping parts. Most floor/wall geometry should remain opaque; selective
trim can suggest ice. Upstairs gallery, connected stair, frozen fountain
beside the route. Drive: pale-blue frosted-looking flat slabs. Blurb:
"Cold walls. Warm welcome."

### Portal House — portal

Near-half stone/slate, far-half violet/teal, one empty upright ring around
the cross-section. Place the ring perpendicular to the front-to-back hall
so the player physically crosses its plane. Fixed floors and stairs join
both halves. Floating steps are off-route set dressing; do not make them
the required way in. Drive: a fixed stone path whose inset colour changes
across the ring. Blurb: "One address. Two sides of the impossible."

### Thundercloud Fortress — thundercloud

Slate grey-blue towers, compact cloud lobes, sheltered royal display rooms.
Cloud is a shaped boundary around stable structure, never fog hiding gaps
in the walking route. Grounded steps reach a true cloud/fortress opening.
Lightning represented by static swept-shape insets in this concept. Drive:
blue-grey slabs with violet edges. Blurb: "Big skies. Bigger ambitions."

### The Void — void

Near-black structural planes (17,17,19) outlined by deep violet major edges.
One tilted ring, two small planet ornaments and one comet are enough to
establish the scale. Keep all projected orbit extents inside the yard and
out of door/foot paths. Three usable levels with sparse geometric star
insets and violet-trim display cases. The circular entry is an open door,
not an opaque teleport disc. Drive: black slabs with violet edge insets.
Blurb: "You bought a house. The universe moved in."

The Void's shop viewport requires a lighter neutral well, or verified
violet-trace contrast against the existing dark well. B1 needs a per-preview
well treatment specified at integration; no new purchase state is needed.

## Materials and token proposals

All flat-colour structural surfaces: SmoothPlastic. Concept highlights do
not mandate Light instances, phototextures, Metal or particles. Suggested
new Theme token names for Fable to reconcile centrally:

| Token | RGB proposal | Use |
| --- | --- | --- |
| HOUSE.FAIRY_CREAM | 232, 218, 184 | Cottage walls |
| HOUSE.FAIRY_MOSS | 75, 103, 56 | Cottage trim |
| HOUSE.AQUARIUM_TEAL | 20, 111, 119 | Dome depth/edge tint |
| HOUSE.ICE_WALL | 185, 215, 237 | Opaque ice wall |
| HOUSE.ICE_ACCENT | 36, 69, 187 | Deep-blue insets |
| HOUSE.PORTAL_STONE | 176, 169, 151 | Near-half wall |
| HOUSE.PORTAL_TEAL | 33, 98, 110 | Far-half wall |
| HOUSE.STORM_WALL | 68, 85, 119 | Grey-blue fortress |
| HOUSE.STORM_CLOUD | 101, 111, 145 | Cloud lobes |
| HOUSE.VOID_WALL | 17, 17, 19 | Only all-black house |
| HOUSE.VOID_TRACE | 91, 35, 181 | Saturated violet edge |

Images are approximate colours. Use actual tokens in final geometry. Royal
and modern family labels do not override these house-specific colour choices.

## Geometry handoff still needed

Final assets follow selected art: proposed route is economical procedural
geometry/exported model hierarchies; runtime House builders remain Fable's
area. Budget target around 200 BaseParts per house must include a measured
interior plan and account for trophy instances. No model counts are claimed.

Model pivot: ground level on structural front-wall plane, front -Z, interior
+Z. Pin to HOUSE_FRONT_LINE. Report frontward stair/path projections
separately; measure all parts through their CFrames, including canopy, rings
and maximum decorative motion bounds. Grounds, walls, doors and stairs need
actual avatar/camera clearance and collision checks. No coplanar claims until
geometry exists. Named trophy points remain Featured, Shelf_1..Shelf_N,
Wall, Record, Plaque_Legacy and Door_Exit, fitted per actual house.

The user has now explicitly requested ambient animation on every Legendary
house, including Portal House. See ANIMATION-HANDOFF.md and
legendary-motion.json for the nine-house specification, and portal-motion.html
for a timing study. These are visual deliverables; runtime motion is not
installed. Collision-bearing floors/stairs remain stationary.

Next individual concept sheets: Crystal Spire and Beached Galleon. Existing
Toadstool/Treehouse/all-green Gloop sheets carry forward. Existing-house
re-themes outside these three remain deferred. Finish catalogue selection
and the 8M slot before replacing the B1 demo's full data set.
