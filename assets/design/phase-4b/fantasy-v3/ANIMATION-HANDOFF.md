# Every Legendary house has ambient animation

The user explicitly requested that Portal House and **all Legendary houses**
animate. This supersedes the earlier unresolved house-FX approval note.
It does not reintroduce removed standalone piggy-bank effects.

Exact proposed components, periods, phases and ranges are in
`legendary-motion.json`. `portal-motion.html` demonstrates the portal's
visual timing with a schematic drawing, not a finished Roblox model.

| House | Ambient signature |
| --- | --- |
| Neon Tower | Colour travelling up fixed window bands |
| Crystal Spire | Three crystal accents breathing out of phase |
| Ice Palace | Deep-blue light travelling along fixed icicle groups |
| Sky Castle | Three roof ornaments orbiting a fixed castle |
| Beached Galleon | Gently swaying decorative sail and warm mast lantern |
| Portal House | Travelling rim colour, rotating inner collar, bobbing off-path steps |
| Thundercloud Fortress | Falling rain bars and slowly sweeping lightning |
| The Void | Violet edge breathing, orbiting planets/comet, window star crossfades |
| Golden Piggy, if earned house is adopted | Gold flank sweep and bobbing skylight coin |

## Physical rules

- The hallway, stairs, floors, bridges, gangplank, door threshold and all
  collision-bearing structural parts stay fixed. Moving parts are decorative.
- The portal is empty air with a continuous physical hallway through it.
  Its decorative floating steps are never the mandatory route inside.
- Motion bounds count toward the house's complete footprint. Include maximum
  orbit radii, bob extents and rotated-part corners in the yard audit.
- Moving props do not become actors, hazards, prompts or loot pickups.
- Use the existing HouseFX pipeline where it supports the requested motion.
  `sway` and `rotate` in this specification describe the desired appearance;
  they are NOT claimed existing HouseFX enum values. Fable maps them to a
  supported transform or extends the pipeline deliberately.

## Timing and visibility

Use smooth periodic interpolation, never on/off flashes. No proposed period
is faster than one cycle per three seconds. Cycle denotes a complete pass,
not the rate of moving between segments. Keep intensity bounded and colours
saturated so motion remains readable without making white patches.

Keep preview animation and world animation consistent. Animate a bounded
set of tagged decorative parts rather than creating/removing parts each
frame. Phase by segment/house so all eight plots do not pulse together.
Any future reduced-motion option may freeze transforms and keep steady
accents; the browser study starts paused if the OS requests reduced motion.

All numeric ranges are design proposals pending model bounds and live
mobile review. Exact final runtime phase attributes and transform mapping
belong to Fable. This handoff does not change runtime source or Studio.
