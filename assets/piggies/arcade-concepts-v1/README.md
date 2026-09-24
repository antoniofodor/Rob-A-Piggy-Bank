# Arcade collection — first four concepts

The six-concept expansion adds Pixel, Circuit Board, Power-Up, Synthwave, Final Boss and Mecha Player. Their exact built-in image_gen prompts are in [expansion-prompts.json](expansion-prompts.json), with source receipts in [expansion-receipts.json](expansion-receipts.json). Finished local models and the ten-piggy gallery are under `../arcade-build-v1/`.

Concept artwork only. No Blender models, animation or Roblox integration created in this pass.
Generated with built-in image_gen using the existing classic pig model as the anatomy reference.
Exact prompts: [prompts.json](prompts.json). Original generated files: [receipts.json](receipts.json).

| Piggy | Tier | Concept |
| --- | --- | --- |
| Player One | Common | [Red and cream plastic](player-one-concept-v1.png) |
| Retro Carpet | Rare | [Printed arcade pattern](retro-carpet-concept-v1.png) |
| Respawn | Epic | [Pixel coat, glow and ascending cubes](respawn-concept-v1.png) |
| Jackpot | Legendary | [Mounted mechanical reels and gold token aura](jackpot-concept-v1.png) |

## Modeling notes

- Preserve the existing base pig geometry and UVs; generated art is a design target, not a topology reference.
- Common is color/material only. Retro Carpet motifs are flat texture artwork with no emission or floating confetti.
- Respawn uses a flat pixel coat plus a small set of animated cubes. Do not build every printed square as separate geometry. Keep the body solid.
- Jackpot housing mounts securely behind the ears. Resolve the concept sheet's inconsistent reel-facing directions into one forward-facing three-reel mechanism with a solid rear housing. Use three separate cylinders for animation; keep the original face and hat space clear.
- Token orbits and pixel streams shown in the concepts indicate intended animation; the PNGs do not contain animation.

The wider 24-piggy lineup is a proposal; this pass establishes one design per tier.

## Player One alternatives

- [Headset v2](player-one-headset-v2.png): simple non-emissive headset and microphone. A Common-tier cosmetic accessory exception is proposed, not implemented. Model a single consistent microphone side and secure band behind the ears.
- [16-bit v2](player-one-pixel-v2.png): original pixel-art direction inspired by old arcade sprites. This is a 2D concept. A pixel-textured 3D version can approximate its shading, but does not automatically reproduce the stepped silhouette of a sprite. Detailed authored pixel artwork fits the current Rare tier rule.
- Both generated with built-in image_gen; exact prompts in `player-one-revision-prompts.json`, receipts in `player-one-revision-receipts.json`. Original concept retained.
