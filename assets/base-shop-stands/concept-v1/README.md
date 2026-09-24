# Base shop stands — concept v1

Design proposal, September 23, 2026. Concept art only; no runtime code, shop
inventory, purchase rules, or base geometry changed.

- [Concept sheet](base-shop-stands.png)
- [Exact generation prompt](prompt.txt)
- Generated with the built-in image_gen tool.

## Design

Two compact open-front market counters share chunky posts, cream trim, teal
lower panels and simple matte surfaces. Distinct roofs and symbols make their
purpose readable before the player can read the sign.

| Stand | Shape and color | Display |
| --- | --- | --- |
| Gadgets | Yellow canopy, lightning sign, broad drawer | Existing Plunger, Bubblegum Bomb and Zapper models |
| Guardians | Coral pitched canopy, paw shield sign | A small static Scrappy display figurine |

Use the image as silhouette and palette guidance. Simplify its small bevels,
fasteners and incidental props for the game. No vendor NPC is required. The
guardian figurine is decorative; the player's actual guardian keeps its kennel
and patrol behavior.

## Proposed scale and placement

- Target overall envelope, including roof: 7 studs wide × 5 deep × 7.5 high.
- Counter surface: approximately 2.6 studs above the lawn.
- Reserve an unobstructed 4-stud approach in front of each counter.
- Prefer both counters along an inside lawn edge, facing into the base. Keep
  the gate-to-house route, piggy interaction area, and guardian route clear.
- The lower image is an illustrative arrangement, not the game's measured
  base layout. Its fence and house arrangement should not be copied literally.

The current plot has existing decor, piggy pedestals, and a front-right kennel.
Final positions must be checked against PlotService's reserved areas and each
house's access route. Do not assume that the left edge is empty or consume an
occupied decoration/pedestal slot automatically. These dimensions and clearances
are design targets, not verified collision measurements.

## Player interaction

1. Approach the front counter to reveal one short Browse prompt; use the
   game's existing keyboard, controller and touch prompt presentation.
2. Activating opens the matching Gadgets or Guardians section directly.
3. Select an item, inspect its existing price/unlock information, then buy or
   equip through the current shop flow. Approaching never spends currency.

For an implementation, reuse the current catalogue and server purchase checks.
Guardian acquisition routes vary: free, directly purchasable, crate-only or
earned entries must keep their existing rules. The stand does not make every
guardian directly purchasable. Keep prices in the menu, sourced from live config,
rather than on permanent 3D signs.

Suggested prompt activation distance: 6 studs, subject to play testing so the
two prompts do not compete. A subtle sign highlight when selected is enough;
avoid perpetual particles or extra animated animals on every player's base.

## Implementation handoff

Build a shared reusable stand shell with separate sign, canopy palette and
display mounts. Use the existing gadget assets and guardian rig appearance for
the displays. Keep decorative parts non-colliding and reserve simple collision
only for the counter body as needed. Verify player access, touch interaction,
prompt selection, camera visibility and guardian navigation in Studio before
integrating into all bases. This proposal does not replace the street shops.
