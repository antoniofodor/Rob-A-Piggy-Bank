# Storm Wolf scale — verified 2026-09-18

Storm Wolf uses a different body mesh from the common pig, Dragon, Phoenix and
Rainbow Tiger. The raw export Body bounds are 10.6529 studs wide; the common
body is 12 studs wide. Its tall mane, ears and lightning disguise this difference
when comparing overall height.

The repository already contains a runtime correction in `Config.LEGENDARY_SCALE`:
`12 / 10.5` (1.142857), based on the earlier measured torso silhouette. The raw
mesh bounds include fur/spikes, so those bounds are not the torso measurement.
`LegendaryModel` applies this uniformly to every mesh and its relative position.
The seat-frame pivot `(0, 0.5, -6.56)` preserves ground/vault seating.

## Current Studio verification

Verified in the connected Rob A Piggy Bank place, using temporary unparented
models and the actual loaded `LegendaryModel` module and published meshes.
The temporary models were destroyed after measurement; no player skin or saved
data was changed.

| Model | Base body width | Displayed legendary Body width |
| --- | ---: | ---: |
| Storm Wolf, full size | 12 | 12.174743 |
| Dragon, full size | 12 | 12 |
| Storm Wolf, 20% miniature | 2.4 | 2.434949 |
| Dragon, 20% miniature | 2.4 | 2.4 |

Both Client and Server Config modules contain the existing correction. No
equipped legendary models were found in Workspace or the player's UI during
inspection, so the particular smaller model reported by the user was not
available for visual inspection.

## Blender versus game

No additional runtime multiplier or Blender resize was made during this audit:
the existing game correction is already active. The raw Blender/FBX export
remains at its original size; viewing that export directly bypasses the game
correction. A source-asset resize would require coordinating the exported row
dimensions, offsets, mounts and runtime correction to avoid applying it twice.

If a particular live model still appears smaller, identify that model/view
before changing scale again. Compare the torso, rather than total height or
the extent of lightning, and check whether that view uses `LegendaryModel`.
