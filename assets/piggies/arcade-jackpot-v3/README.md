# Jackpot - jeweled shades and payout revision 3

Starts from the preserved Legendary v2 model. Adds curved gold sunglasses with dark lenses, temple arms, a bridge and 32 faceted champagne stones. Replaces the hovering tokens with two machine-mounted payout chutes and twelve embossed coins that emerge, tumble outward, fall and shrink. Hidden resets occur inside the chutes. Each coin repeats after three seconds within the existing six-second reel loop.

The refreshed burgundy coat combines a fine diamond pattern, sharp gold stars and diamonds, and swept double gold bands. Golden ear interiors, burgundy-banded gold feet and a detailed gold tail carry the palette around the model. The ivory snout keeps the face readable. Six new 1024px body/trim color, metalness and roughness maps are baked into the original UVs. Reel textures are preserved.

94 accessory meshes, 7,624 accessory triangles; all meshes closed; base geometry and UVs unchanged. 330 visible coin-flight samples clear the pig envelope. Six-second loop closure below 0.000001. Accessory and complete FBX round trips verified within 0.000001 studs.

Review only; v2 remains installed. No uploads or runtime configuration changed. Installation needs the revised accessory asset, six PBR maps and regenerated sampled motion data including coin scale tracks.

Preview: http://127.0.0.1:8841/arcade-jackpot-v3/index.html
Model: ../legendary/jackpot/package/jackpot-v3/jackpot-jackpot-v3.blend

Build: build.py uses geometry.py and paint.py. render_motion.py renders 72 frames for the six-second preview; package_motion.py packages the animated WebP. show_blender.py safely appends the review scene through Blender MCP.
