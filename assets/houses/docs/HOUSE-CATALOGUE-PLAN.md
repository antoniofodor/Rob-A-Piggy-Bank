# House catalogue and price proposal — September 16

Status: proposal for discussion, not approved prices or implemented content.
The user approved the shared themed trophy-room approach, and asked to plan
house count, price coverage and whether existing houses should move.

## Recommendation: 18 houses, nine existing and nine new

> **Superseded in part, September 16 (Fable).** The prices, the count and
> the rarity bands below stand. The **concepts do not**: the designer asked
> for fictional, fantasy houses rather than real-estate, so the slots are
> re-briefed in `assets/houses/docs/HOUSE-TIER-BRIEF.md` revision 2 (toadstool, fairy
> lantern, treehouse, gloop, fishbowl, gingerbread, crystal, ice palace,
> galleon, portal, thundercloud, the void at 1B; the golden piggy as an
> earned, unpriced house) with stable ids. The three realistic mockups under
> `assets/houses/concepts/2026-09-16/` are kept as reference only.


Assumption: "up to 1 billion" means the highest individual house costs 1B,
not a 1B combined catalogue. Keep all existing house prices and appearances;
add two Rare, two Epic and five Legendary houses. Rarity follows the current
shared thresholds: Rare 100K, Epic 1M, Legendary 10M. No new rarity tier is
required. The four 150M–1B houses are premium options within Legendary.

| House | Coin price | Rarity | Status |
| --- | ---: | --- | --- |
| Starter Shack | 0 | Common | Existing |
| Cosy Cottage | 35,000 | Common | Existing |
| Brick Townhouse | 120,000 | Rare | Existing |
| Garden Bungalow | 250,000 | Rare | New concept needed |
| Suburban Villa | 400,000 | Rare | Existing |
| Coastal Villa | 750,000 | Rare | New concept needed |
| Stone Manor | 1,400,000 | Epic | Existing |
| Hilltop Mansion | 2,500,000 | Epic | New concept needed |
| Midnight Modern | 5,000,000 | Epic | Existing |
| Sunset Sky Villa | 8,000,000 | Epic | Mockup available |
| Neon Tower | 15,000,000 | Legendary | Existing |
| Emerald Chateau | 25,000,000 | Legendary | Mockup available |
| Marble Palace | 40,000,000 | Legendary | Existing |
| Sky Castle | 80,000,000 | Legendary | Existing |
| Royal Observatory | 150,000,000 | Legendary | Mockup available |
| Skyline Penthouse | 300,000,000 | Legendary | New concept needed |
| Imperial Estate | 600,000,000 | Legendary | New concept needed |
| Celestial Citadel | 1,000,000,000 | Legendary | New concept needed |

New names and price assignments are provisional. Three exterior mockups exist
in `assets/houses/concepts/2026-09-16/`; their existence is not model approval.

## Why this count

Eighteen is a recommended scope, not a mathematical requirement. Two current
Common houses cover the beginning. Four Rare and four Epic houses provide
regular mid-game milestones. Eight Legendary houses cover 15M–1B with more
frequent purchase goals instead of a jump directly from 80M to 1B. Most
adjacent paid prices are roughly 1.5–2.7 times apart; the original 35K–120K
step remains. All models need distinct silhouettes, not just recolours.

## Capacity and pace decision required

The existing maximum capacity is 96,904,045 coins, from
`floor(5000 * 1.4^19 * 1.19^20)`. Four proposed houses exceed it. Current
`auditEconomy` intentionally rejects them. Do not add unbuyable prices or
weaken the audit to make the proposal pass.

Preferred direction if 1B is the new individual target: design additional
late-game capacity progression reaching at least 1B. This is a separate
balance change that must consider upgrade affordability, income, rebirth
gates, robbery payouts/losses and vault fill pacing. Do not simply multiply
all early-game balances or let income scale up automatically with capacity.

Alternative: staged house payments with progress stored across sessions.
This permits a cumulative 1B purchase at today's capacity, but moves coins
out of the robbable piggy and changes the game's risk economy. It requires
an explicit decision about refunds, commitment and robbery exposure.

Prices alone do not set progression time. Tune after choosing target play
hours and the capacity approach; the former plan's ~400M total catalogue
budget no longer describes a catalogue containing a 1B house.

## Ownership and trophy rooms

Current houses are an ordered ladder stored as numeric `houseLevel` and
`houseShown`. Inserting rows directly would change what existing owners have.
Before expanding, map legacy levels to stable house IDs and an owned-house
set. Preserve every house previously earned and the currently displayed
house. Newly inserted lower-priced houses are optional missing purchases
for existing owners, not requirements to regain their previously owned home.
The exact purchase-unlock rules remain a design decision.

All houses share achievement/trophy records and full menu access. The
September 17 direction in `HOUSE-TROPHY-ROOMS.md` supersedes equal physical
display capacity and separate fallback rooms: interiors are walk-in spaces
inside each house, and larger homes display more earned items at once.
Every home retains the achievement cabinet, records book and Legacy plaque.
Exact slot counts are proposed there; they do not gate achievement ownership
and are separate from the house's economy rules.

## Build batches

1. Decide the price ceiling/payment approach and preserve ownership by IDs.
2. Finish the four new Rare/Epic designs and the 25M Chateau; these fit the
   existing maximum capacity. Prototype the shared trophy room alongside them.
3. Build the four 150M–1B exteriors once their purchase path and pacing work.

Fences remain deferred. No live Config values were changed for this proposal.
