# Store redesign · September 18, 2026

The four street stores now have open display windows, physical fascia lettering
and rooftop emblems. The window frames and doorway use separate jambs and rails;
the previous opaque backing parts concealed the shop interiors. Tall window-case
partitions are removed, so the stock and shopkeeper can be seen from outside.

Each interior has a finished floor, inlaid seams, welcome mat, paneled lower walls,
fluted counter, till, product shelves, feature wall, and two warm pendant lights:

- **Piggy Outfitters:** pink joinery, gift boxes, gold-framed mirror and swatches.
- **Home & Garden:** green joinery, terracotta plants and timber display ledges.
- **Wheels & Kit:** orange work counter, kit cases, wheel and tool display;
  a tyre bench replaces the oversized decorative pavement ramp.
- **Lock & Key:** blue joinery, dark equipment cases and gold key display.

`Shared/ShopFront.luau` owns the shell and entrance; `Shared/ShopInterior.luau`
owns the decorative fittings. Both use the existing `Config.SHOP_ROOM` plan.
PlotService continues to own floors, vaults and residents. Door tags, proximity
prompts, collision barriers, vault approach and economy values are preserved.
Merchandise is seated by its bounding-box bottom rather than its builder's pivot.

Validation: both modules compile with Luau; the existing 222-check audit suite
passes; Rojo builds `StoreRedesign-review.rbxlx`. All four exteriors and interiors
were inspected in a Studio playtest. The changes are local, not published.
Runtime checks also confirmed all four shop tags and prompts, clear 2.5-stud
entrance approaches, noncolliding/nonqueryable fittings, and a 0.04-stud seating
gap for all three merchandise displays. No store-related startup errors occurred.

The elongated leaves and pig-snout emblem use Roblox's built-in sphere mesh,
which supports independent axis scaling ([Roblox reference](https://create.roblox.com/docs/reference/engine/classes/SpecialMesh)).
