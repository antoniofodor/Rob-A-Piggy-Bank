# Rebirth icons v1

Five reusable **1254 × 1254 transparent RGBA PNGs**, based on the game's Classic
Pink piggy model, oak tree, and Acorn references. The piggy illustrations have
clean nostrils: the old black `NostrilPreview` helpers are absent.

## Import these files

| File | Use |
| --- | --- |
| [classic-piggy.png](icons/classic-piggy.png) | Plain piggy for general HUD, upgrades, inventory and other menus |
| [classic-piggy-coins.png](icons/classic-piggy-coins.png) | Income/money benefit card; piggy with a coin stack and deposit coin |
| [acorn-tree.png](icons/acorn-tree.png) | Online Acorn growth benefit card |
| [rebirth-piggy-emblem.png](icons/rebirth-piggy-emblem.png) | Complete static piggy-and-arrows icon for the rebirth button/header |
| [rebirth-arrows.png](icons/rebirth-arrows.png) | Arrows only, with an empty transparent center, for independent rotation |

## Using them

- Upload `icons/*.png` through your normal Roblox image workflow. No uploaded
  asset IDs or runtime bindings are included.
- Keep image labels square and their backgrounds transparent. The original
  square canvases include padding; they can be used directly without the
  crop rectangles needed by the pin-lock kit.
- Start around 48–64 px for benefit-card illustrations and 32–40 px for the
  complete emblem. Review small-size readability in your actual UI; the tree
  has more detail than the simple emblem.
- Keep text, percentages and button backgrounds separate from the images.
- The standalone piggy is the canonical reusable version for this art set.

### Optional rotating arrows

Use two centered square image labels in the same container:

1. `rebirth-arrows.png` fills the container, centered with a center anchor.
2. `classic-piggy.png` sits above it at approximately **70% of the container's
   width and height**, also centered.

Rotate only the arrow image around its center. Keep the piggy upright. Leave
room for rotation and avoid clipping the ring with the button's rounded frame.
This is a flexible layered version, not a pixel-identical reconstruction of the
combined emblem. The ring is a static PNG; animation is left to your UI code.
For a still icon, use the combined emblem directly.

## References and validation

- [Corrected model render](references/classic-piggy-model.png) is an additional
  transparent 1024px render of the existing `pig_parts.blend` geometry in Classic
  Pink colors. Fur and old nostril preview helpers were excluded from this
  render. The source model itself was not modified.
- Final illustrations were created using the **built-in image_gen tool**.
  [Full prompt set](source/prompts.json) records each reference and generated source.
- [manifest.json](manifest.json) records dimensions, alpha ranges and visible bounds.
  All five PNGs were checked for real alpha transparency; the arrow layer's
  center is fully transparent. The final pig illustrations and corrected model
  render were visually checked for the unwanted black nose pieces.
- Original generated PNGs are preserved without pixel post-processing.

Related: [rebirth concepts](../rebirth-concepts-v1/README.md). The redesign
guide this was authored against is retired; the shipped design and its
history live in the header of `src/ReplicatedStorage/Shared/Rebirth.luau`.

Status: artwork ready for import; not uploaded or wired in Studio.
