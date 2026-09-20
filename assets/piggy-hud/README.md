# Piggy balance icon v2

`piggy-balance-v2.png` is the generated transparent image for the capacity HUD.
Generated with the built-in image generation tool; the exact prompt is in
`piggy-balance-v2-prompt.txt`. The source image is preserved without editing.

## Integration

Imported under the experience's owner as image `115881888441059`, and live:
`PiggyPanel.ICON_IMAGE` in `src/ReplicatedStorage/Shared/PiggyPanel.luau` names
it, and the card draws an ImageLabel at 94x94 with `ScaleType.Fit`, following the
existing desktop/compact sizing rather than a badge or a floating coin.

Emptying that field falls back to the drawn pig, which is why that code is kept:
a moderated or deleted image would otherwise leave a hole in the card. The same
applies to a wrong id -- an ImageLabel reads back exactly what it was given
whether or not the asset resolves, so check it in Play rather than by property.
