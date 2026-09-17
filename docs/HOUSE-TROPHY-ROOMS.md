# House trophy rooms

## Confirmed direction — September 16

The user wants earned achievements and trophies displayed inside houses
instead of in the yard. Higher-tier exterior catalogue concepts are underway;
fence expansion remains deferred. Interior implementation has not started.

## Recommended design (proposal, not yet implemented)

Use a door interaction to enter a separate themed room within the same
server. The exterior remains plot scenery. A separate room avoids rebuilding
every facade as a walkable shell and permits the same collection in every
house, including the starter shack. No separate Roblox place or server hop.

Build one shared room/display system with house-specific themes:

| Exterior family | Interior treatment |
| --- | --- |
| Shack / cottage | Timber shelves, plaster, warm lights, modest furnishings |
| Townhouse / villa / manor | Framed achievement wall, cabinets, wood or stone trim |
| Modern / Neon Tower | Clean display cases, dark trim, restrained accent lighting |
| Palace / château / castle | Arches, stone, velvet panels and brass details |
| Observatory concept | Curved display alcoves, navy panels and brass trim |

These are palette directions, not approved interior art. Use the same named
display locations in each template: featured trophy, collection shelves,
achievement wall and career record. Larger houses can feel grander without
unlocking additional achievement capacity or gameplay advantages. A new house
theme must have a tested default room fallback.

## Existing systems to reuse

- `TrophyService.counts/state` already derives victims, total stolen, thieves
  caught and wanted escapes from player data. Keep this authoritative award
  logic and the existing saved trophy ownership/progress.
- `Decor` contains the current trophy model builders. Adapt the display
  mounting/scale for cabinets and walls instead of inventing a second award
  system. Preserve meaningful bought plinth finishes as interior bases.
- Replace lawn placement of earned trophy decorations with interior display
  locations. Remove only their yard slot references after the interior is
  ready; preserve ordinary yard decor and all earned ownership.
- Awarded trophies appear automatically. Suggested optional customization:
  choose a featured trophy; unearned achievements appear as labelled progress
  plaques, clearly different from earned trophies.
- Save choices by stable achievement/display IDs, never by world coordinates
  or house tier number. Changing houses or rebirthing must not reset them.

## Visiting and gameplay rules to settle before implementation

- Recommend allowing visits so friends can inspect earned trophies. Visitors
  can view but cannot edit the owner's displays; ownership stays server-side.
- Recommend preventing entry during an active robbery/pursuit or while carrying
  loot, so the room cannot become a teleport escape or safe place for loot.
  The outdoor piggy remains governed by the normal robbery rules.
- Server validates distance to the door, entry/exit and room membership.
  Exit returns to that house's doorstep. If the host leaves or changes the
  house, visitors need a safe exit without losing their own state.
- Build rooms on demand in a reserved part of the map, not at extreme world
  coordinates. Test streaming/camera/collision and multiplayer isolation;
  clean up empty rooms. Match capacity to the configured server size.

## Suggested first implementation slice

One basic room, one house door, working entry/exit, current earned trophies
and a readable achievement wall. Verify old ownership survives, new awards
refresh, guests cannot edit, and entry cannot bypass pursuit. Then apply
three visual families (cozy, modern, royal), with explicit mappings/fallbacks
for all existing house styles and the chosen exterior concepts.
