# Smooth shop icon system — review v1

**[File index: all model exports, icon sizes, textures and Blender sources](FILES.md)**

Actual Blender renders, authored from editable geometry. No generated illustration
is used in this pack. The user requested the shared piggy snout emblem on the
standard coin and every crate. All renders have transparent backgrounds and no
baked glow, particles, labels, checkmarks or requirement text.

## Review

Open `index.html`. Select either upgrade, inspect the coin at 32/48/64/128 pixels,
and compare shop/open-lid/effect-study modes for the three crates. The browser
effect study illustrates motion; it is not footage from Roblox. `contact-sheet.png`
is the static overview. The icons are uploaded and connected in the game source;
see `roblox-uploads.json` for the IDs and source hashes. Game-model installation
and world effects remain separate from the shop UI.

## Contents

- 18 base icons plus a straight-on currency coin variant (19 PNGs total).
- `defend-rob-sheet.png`: six additional upgrades—vault lock, fence, lockpicks,
  bigger sack, speed boots and Sneak—with source Blender files and all UI sizes.
  Sneak shows the existing resident NPC crouching with the piggy-snout robbery
  bag, linked gold necklace, snout medallion, and original hair cutout.
- `coin-front.png`: full frontal snout coin for shop balances and HUD currency.
  Use `small/coin-front-128.png` for a 32–64px display, with transparent background
  and ImageLabel ScaleType set to Fit. `coin.png` keeps the angled presentation.
- `*.png`: 768px transparent masters. `small/`: 32, 48, 64, 128, 256px exports.
- `sources/*.blend`: editable models, materials, cameras and consistent studio lights.
- `crates/<tier>/*.glb` and `.fbx`: model-only exports, embedded palette, separate Body/Lid.
- `crates/<tier>/manifest.json`: triangle counts, real hinge and effect coordinates.
- `CrateDefinitions.luau` / `CratePresentation.luau`: optional client presentation.
- `ShopIcons.luau`: packaged copy of the runtime icon registry and image helper.
  The canonical source is `src/ReplicatedStorage/Shared/ShopIcons.luau`.
- `models/plunger/`: new hollow-cup plunger model in GLB/FBX, with import notes and
  export validation. Supplies now shows the plunger, gum and golden bone together.
- `models/bubblegum-bomb/` and `models/golden-bone/`: standalone game exports,
  packed palettes and validation reports, matching the approved icon designs.
  Optional `models/SupplyEffects.luau` adds fuse sparks or golden glints in-world.
- `models/coin/`: the standard snout coin as a separate GLB/FBX game model,
  in addition to its reusable PNG icon.

The existing Acorn storage crate is a different gameplay prop and is untouched.
The Common artwork is a visual tier; it does not add a purchasable Common crate
or change existing themed crates, prices, drop odds or reward pools.

## Crate import and world effects

Prefer GLB; set import units to studs and preserve Y-up / front +Z. Models were
authored in Blender Z-up / front -Y and converted by the exporter. FBX is also
included with FBX Unit Scale. Confirm dimensions against the tier manifest.
Use the packed palette for the model's toy/metal/timber materials. All effects
are separate from the base materials, so the shop needs no particles or lights.

After importing, retain Body and Lid. Create an invisible, anchored, non-colliding
BasePart named CrateRoot at the **exported bottom-center origin**, not the center of
the overall bounding box. The clasp and crown make that bounding box asymmetric.
Set the Model pivot to CrateRoot. The source Blender scene and GLB root preserve
the intended origin; the `FX_*` empty locators are references, not Roblox emitters.

Install both presentation modules together. From the client:

```lua
local fx = CratePresentation.attach(crateModel, "legendary", crateRoot, "world")
-- Later, when the game authorizes the visual opening:
fx.open(crateModel.Lid)
-- For distance culling:
fx.setEnabled(false)
-- Before replacing or pooling a model:
fx.destroy()
```

The helper uses built-in spark/smoke textures, creates anchored effect locations,
and opens the separate lid about the recorded rear hinge. Keep the display meshes
anchored and un-welded to one another when opening with this helper. It does not
award items or listen to purchase remotes. Run presentation only once per client,
not on both client and server. Calling `attach(..., "shop")` creates no emitters,
lights or repeating tweens. Using the PNG icons needs no presentation helper.

Common has sparse warm sparkles. Rare adds cyan motes and a cool seal light.
Legendary adds gold-tipped violet sparks, faint rising wisps and a pulsing light.
No continuous RenderStepped loop is used. Destroying the model cleans up the helper;
call destroy explicitly when pooling. Open and idle effects need final Studio QA.

## UI integration

Six category icons are mounted in ShopRevamp. ShopUpgrades uses PNG icons for all
eight upgrades, selection checks, glowing borders and level pills with rebirth locks.
Artwork crops are generated from PNG alpha bounds by the packager. Theme.coin uses
the straight-on snout coin for currency badges and prices. Supplies uses the
plunger, bubblegum bomb and golden bone images. Crate cards and collection details
use common artwork for themed crates, and distinct rare/legendary artwork for
the corresponding tier crates. No world particles are mounted in the UI.

The shell allows the new gradients. Labels, prices, badges and selection borders
remain native, responsive elements. Purchase callbacks, prices and server state
are unchanged. Rojo syncs the runtime source; publishing the place is separate.

## Rebuild

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 6 --python-exit-code 1 --python blender/shop/build_icon_system.py
python blender/shop/package_icon_system.py
```

The packager needs Pillow. The builder preserves the original pig master and
validates its hash. Crate exports exclude cameras and studio lighting.
