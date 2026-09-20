# Walk-in house displays

Updated September 17, 2026. The user approved the three-station direction.
This is a design/integration plan, not a claim that the feature has shipped.

## Approved direction

- Every house has a physical walk-in interior inside its exterior in the existing world. No door teleport, separate room or reserved room region.
- Earned trophies and achievements move inside instead of occupying the yard.
- Five display functions are provided through three essential stations.
- Larger houses display more items at once and may have extra rooms/floors. Every player retains access to the full collection through menus, including in the starter house.
- Essential stations stay on the entrance floor; optional galleries may be upstairs.
- Furnishings match the home: worn, dingy wood in the starter shack; grander displays in larger houses; green slime furniture in Gloop.
- Visitors inspect the owner's collection and records. Only the owner edits displays.

This supersedes earlier separate-room, remote room allocation, teleport entry/exit and equal physical display capacity proposals. It does not change house prices, progression gates or acorn capacity rules.

## Five staples, three stations

| Station | Physical display | Existing mount contract | Interaction |
| --- | --- | --- | --- |
| Achievement cabinet | One owner-selected featured trophy | `Featured` | Opens full achievements/collection menu |
| Achievement cabinet | Selected earned trophies, medals or collection pieces | `Shelf_1` through `Shelf_N` | Same menu; owner manages displayed items |
| Cabinet / attached achievement board | Highlighted achievements and labelled milestone progress | `Wall` | Same menu; unearned progress looks distinct from earned awards |
| Career records book | Book on a desk or compact wall shelf | `Record` | Opens owner's career records |
| Legacy plaque | Earned Legacy stars | `Plaque_Legacy` | Opens owner's Legacy details |

The featured trophy can sit on the cabinet in small homes or on a separate pedestal in larger homes. The achievement board can be built into the cabinet: five functions do not require five pieces of furniture. The Legacy plaque remains distinct from ordinary achievement plaques.

Core career records: different piggy skins robbed, lifetime coins stolen, thieves caught and most-wanted escapes. Read existing authoritative counters. Additional stats can appear in the menu without extra furniture or floating HUD panels.

### Existing trophy content

Reuse existing trophy identities and award logic: piggy-skin collection, stolen wealth, defence, wanted escapes, best robbery streak, robbery rank, clean robberies, seasonal progress, wanted appearances and harvesting. These are collection choices, not ten mandatory furniture stations. Gold cups/medals in art renders are examples only; they must not replace all existing trophy art or grant ownership.

## Proposed physical capacities

The larger-home display principle is approved. These exact counts are proposed art targets pending furniture/avatar fit checks, not implemented Config values or gameplay unlocks.

| Home rarity | Featured trophy | Collection positions | Achievement plaque positions | Records book | Legacy plaque |
| --- | ---: | ---: | ---: | ---: | ---: |
| Common | 1 | 2 | 1 | 1 | 1 |
| Rare | 1 | 4 | 2 | 1 | 1 |
| Epic | 1 | 6 | 3 | 1 | 1 |
| Legendary | 1 | 10 | 4 | 1 | 1 |

Collection positions count individual mounted items, not furniture shelves. One shelf may contain several positions. Achievement plaque positions are additional to the Legacy plaque. A compact house can integrate all three stations into one wall of furniture while preserving each interaction. Keep one featured selection at every tier as the focal point.

If a silhouette cannot safely fit its target, revise furniture/layout and record the exception for review. Do not shrink trophies until unreadable, block the doorway or exceed the plot envelope.

All achievements remain earnable and visible in the full menu at every tier. Switching to a smaller home shows the available subset of saved selections; preserve overflow choices and earned ownership. A larger home restores those choices. Rebirth must not erase trophy records.

## Mount and interaction contract

Preserve semantic names `Featured`, `Shelf_1..Shelf_N`, `Wall`, `Record`, `Plaque_Legacy`, `Door_Exit`. `Door_Exit` is a physical doorstep reference, not a teleport trigger. Runtime templates may wrap these as `Mount_<name>` Parts; Fable should normalize Attachment/Part wrappers rather than changing achievement IDs by house.

For extra plaque positions, propose `Wall_2..Wall_N`, retaining `Wall` as the first position. Fable should finalize this extension before all templates expand. Do not silently rename `Wall` to `Wall_1`.

Each essential station needs an interaction anchor and a clear standing point:

| Station | Interaction anchor | Standing marker |
| --- | --- | --- |
| Achievements | `Interact_Achievements` | `Stand_Achievements` |
| Records | `Interact_Records` | `Stand_Records` |
| Legacy | `Interact_Legacy` | `Stand_Legacy` |

These six markers already exist in Gloop v2 art. They are invisible helper markers, separate from trophy mounts. Supply usable slot dimensions and orientation in the eventual asset contract so existing trophy builders can fit without clipping.

Approaching reveals a prompt. Tap, keyboard interaction or controller input opens the menu; walking past never opens it automatically. Entering the house itself requires no menu. Server checks interaction distance, plot owner and edit permissions. Guests see the host's records. Keep menus usable on mobile.

## Ownership, migration and gameplay

- Reuse `TrophyService.counts/state`, existing saved ownership and `Decor` builders. Preserve bought plinth finishes as interior bases.
- Save choices by stable achievement IDs and logical slots, never world coordinates or tier numbers. New awards refresh progress immediately. Proposed default: fill an empty compatible slot without overwriting owner choices.
- Migrate lawn trophies only after interior displays work. Preserve ordinary yard decor, all earned awards and saved progress.
- Physical interiors must not grant invulnerability, pause pursuit or protect carried loot. Earlier teleport entry restrictions are superseded; Fable must validate existing robbery/pursuit behavior for walk-in homes.
- If a house changes or its owner leaves, handle occupants safely and close menus whose host/target disappeared. Remote room membership is unnecessary.

## Work split

**GPT: physical design.** Themed furniture, meshes, display mounts, standing space, clear sightlines, collision drafts and render review. Supply measured slot dimensions, footprint and part counts. Essentials on the entrance floor; optional galleries upstairs.

**Fable: planning/runtime.** Finalize slot schema and capacities, owner/guest menus, prompts, permissions, trophy fitting, persistence, migration, house switching and multiplayer/mobile validation.

## First implementation slice

1. Validate one compact Common layout containing all five functions and three prompts.
2. Wire the three menus to existing authoritative records; test an owner and visitor.
3. Validate a larger furnished home against the same contract. Gloop v2 currently has four collection mounts and one wall board: it needs two more collection positions and additional wall positions to reach the proposed Epic target.
4. Test full collection access, preserved ownership and saved display overflow when switching between smallest/largest homes and after rebirth.
5. Check real avatar/camera clearance, trophy scale, pursuit behavior and mobile prompts before migrating lawn trophies or rolling out the catalogue.

Art examples: `assets/houses/gloop-house-v2/` and `treehouse-v2/`. Their existence and offline checks do not mean runtime integration or the proposed capacity ladder has shipped.
