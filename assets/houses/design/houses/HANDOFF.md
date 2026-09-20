# B3 / 4b.4 — nine new exterior designs

**SUPERSEDED:** see `../fantasy-v2/HANDOFF.md`. All nine concepts and new IDs
below are historical references, replaced by the fantasy brief. Do not
integrate these proposed catalogue rows.

Status: all nine have exterior concept sheets; none is a final Roblox model.
Six sheets are new; Chateau, Sunset Villa and Observatory carry forward the
earlier concepts. No source builder, Config row, asset upload or published
place was changed. Exact image prompts are in `../prompts.json`; earlier
three prompts are in `assets/houses/concepts/2026-09-16/prompts.json`.

**New user direction:** houses must be physically walk-in, with size/condition
and accessible floors progressing by house. Before producing final geometry,
coordinate the exterior massing with `../rooms/REVISION-WALK-IN.md` and a real
door opening/stair route. Do not build solid scenery blocks behind a fake door.

## IDs, envelopes and build route

New stable IDs below are proposed by this handoff. Fable owns the final
catalogue registry and must use one agreed set before integrating. Existing
IDs are retained exactly as B1 specifies. JSON mapping: `catalogue-design.json`.

Dimensions are design envelopes in studs, not measurements of generated
images. Width includes roof overhang; depth includes porch/steps. Structural
front wall at local z=0, exterior faces -Z, volume extends +Z; seating adapter
pins that wall to HOUSE_FRONT_LINE. Steps may extend to -Z and must be measured
separately against available front clearance. The geometry stage must report
both wall envelope and complete structure bounds; none may exceed width 60.

| id | Name / proposed price | W × D / visible storeys | Roof height target | Route / target exterior parts |
| --- | --- | --- | ---: | --- |
| gardenbungalow | Garden Bungalow / 250K | 32 × 25 / 1 | 14 | House builder / 100–130 |
| coastalvilla | Coastal Villa / 750K | 36 × 30 / 2 | 26 | House builder / 120–150 |
| hilltopmansion | Hilltop Mansion / 2.5M | 40 × 34 / 3 | 36 | House builder / 150–180 |
| sunsetvilla | Sunset Sky Villa / 8M | 42 × 34 / 5 | 51 | House builder / 150–190 |
| emeraldchateau | Emerald Chateau / 25M | 48 × 36 / 4 | 48 | House builder / 175–200 |
| royalobservatory | Royal Observatory / 150M | 44 × 38 / 4 | 58 incl. telescope | House builder / 150–185 |
| skylinepenthouse | Skyline Penthouse / 300M | 40 × 38 / 8 | 78 | House builder / 160–190 |
| imperialestate | Imperial Estate / 600M | 56 × 44 / 6 | 64 | House builder / 175–200 |
| celestialcitadel | Celestial Citadel / 1B | 52 × 46 / 7 | 84 | House builder / 180–200 |

All routes favour flat-colour LowPoly geometry and avoid new image/mesh
uploads. Targets are estimates, not achieved counts. Interior and trophy
geometry must have an additional measured budget; do not conceal those costs
inside the exterior count. Preserve visible heights while adjusting floor
plans for walkability. The rendering perspective exaggerates some depths;
the dimensions above are the design constraint.

## Silhouette and player-facing blurb

| id | Defining silhouette | Blurb |
| --- | --- | --- |
| gardenbungalow | Low L-shape, off-centre porch, cross-gable roof | A porch, a garden, and room to put your feet up. |
| coastalvilla | Two uneven roof heights, central upper balcony | Sunny walls, blue shutters, and a balcony to boast from. |
| hilltopmansion | Three stepped gables, tall square front bay | Steep roofs and a window for every story. |
| sunsetvilla | Staggered vertical terraces, broad flat pergola crown | Five floors, fresh air, and the best seat on the street. |
| emeraldchateau | Emerald mansard, integrated round corner bays | Green roofs, grand windows, and a proper front entrance. |
| royalobservatory | Large gold dome and chunky telescope | A home with its sights set higher. |
| skylinepenthouse | Three offset blocks, open rectangular crown | The skyline has a new owner. |
| imperialestate | Broad stepped terraces, square central pavilion | Enough grandeur to fill the whole address. |
| celestialcitadel | Tapered central spire, unequal side towers | The street ends here. The bragging does not. |

## Colour / driveway handoff

Existing Theme neutrals can provide cream, ivory, cocoa and brass. Distinct
architectural roof colours need semantic Theme.HOUSE tokens added by Fable;
the following are colour proposals, not permission to put literals throughout
builders. Flat SmoothPlastic only, including driveway surfaces.

| id | Walls / roof / trim tokens | Proposed drive |
| --- | --- | --- |
| gardenbungalow | HOUSE.Sage / HOUSE.Cocoa / PAPER | SAND_DEEP, plain perimeter edging |
| coastalvilla | PAPER / HOUSE.Coral / HOUSE.Teal | PAPER_DEEP, cream edging |
| hilltopmansion | PAPER_DEEP / HOUSE.Plum / PAPER | SAND_DEEP, dark narrow edge |
| sunsetvilla | PAPER / INK / HOUSE.Coral | PAPER_DEEP, cocoa edge |
| emeraldchateau | PAPER_DEEP / HOUSE.Emerald / GOLD | SAND, cocoa edge |
| royalobservatory | PAPER / HOUSE.Navy / GOLD | PAPER_DEEP, navy edge |
| skylinepenthouse | HOUSE.Navy / INK / PAPER | SLAB, ivory edge |
| imperialestate | PAPER / HOUSE.Burgundy / GOLD | PAPER_DEEP, burgundy edge |
| celestialcitadel | PAPER / HOUSE.Cobalt / GOLD | SLAB, ivory edge |

Proposed central tokens: Sage #8C9B73; Cocoa #594338; Coral #BC765C;
Teal #386C73; Plum #625363; Emerald #286B51; Navy #34435F;
Burgundy #71424A; Cobalt #3C5290. Use gold sparingly. Existing standard
window colours should be reused; ground floor lit, upper windows unlit.
Earlier three sheets include fine detailing/material cues that must be
simplified to flat colour and the part budgets before modeling approval.

## Geometry delivery checklist (still pending)

Each final model needs Pivot/front convention, Door_Entrance, actual wall
void, interior floor/stair alignment, measured parts/extents, material scan,
same-facing coplanar scan, camera/headroom check, and a pavement screenshot.
No concept screenshot proves any of these. Fable seats and wires the final
builder/model and validates purchase/ownership; GPT reviews its visual match.
