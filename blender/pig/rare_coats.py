"""Rare animal-coat art direction. IDs are asset proposals, not runtime rows."""
SPECS = {
    'strawberrycow': dict(name='Strawberry Cow', parent='cow', base=(255,209,221), ink=(193,47,99), nose=(234,119,155), ear=(255,162,188), pale=(255,234,240)),
    'cookiescream': dict(name='Cookies & Cream', parent='cow', base=(255,238,205), ink=(68,39,28), nose=(163,108,80), ear=(231,181,141), pale=(255,247,228)),
    'watermelon': dict(name='Watermelon', parent='ladybird', base=(86,169,58), ink=(36,37,26), nose=(242,88,110), ear=(255,146,154), pale=(251,98,124)),
    'peppermint': dict(name='Peppermint', parent='tiger', base=(255,248,233), ink=(208,37,66), nose=(210,49,69), ear=(255,178,181), pale=(255,248,233)),
    'glacier': dict(name='Glacier', parent='tiger', base=(239,250,255), ink=(66,155,204), nose=(110,185,221), ear=(170,222,239), pale=(218,239,250)),
    'bubblegumleopard': dict(name='Bubblegum Leopard', parent='leopard', base=(250,162,207), ink=(156,34,121), fill=(219,78,162), nose=(215,97,163), ear=(255,201,223), pale=(255,222,238)),
    'honeycomb': dict(name='Honeycomb', parent='giraffe', base=(155,84,15), ink=(247,183,38), nose=(235,152,30), ear=(255,205,105), pale=(255,222,141)),
    # ---- docs/PIGGY-SKIN-MAP.md 6d/6e -------------------------------------
    # Deep Sea. The cow's blotch field reads as koi markings unchanged -- a
    # koi IS white with soft-edged orange patches, which is what that
    # generator draws. Ink is the vermilion of a kohaku rather than a pure
    # orange; pure orange goes muddy against the white at bake gamma.
    'koi': dict(name='Koi', parent='cow', base=(252,250,246), ink=(226,84,38), nose=(238,146,124), ear=(255,196,180), pale=(255,252,248)),
    # Dino. The tiger's rings become dorsal banding. Base is a desaturated
    # teal rather than a saturated one: this coat has to read against a
    # catalogue that already has Aurora and Toxic in it, and a bright teal
    # would be a third of those rather than a different animal.
    'raptor': dict(name='Raptor', parent='tiger', base=(64,138,126), ink=(24,44,50), nose=(96,170,158), ear=(146,202,188), pale=(226,238,220)),
    # OG. THE PIG AS THE OBJECT THE GAME IS NAMED AFTER -- a china money box,
    # cobalt on cream. The giraffe's cells are panels of glaze and its lanes
    # are the crazing between them, which is the same field read as pottery
    # rather than as an animal. Cobalt rather than a deeper pink because a
    # subtle crazing reads as dirt at pedestal range; delftware is legible
    # from across a lawn and is funnier.
    'piggybank': dict(name='Piggy Bank', parent='giraffe', base=(246,243,234), ink=(38,70,146), nose=(226,216,198), ear=(236,228,212), pale=(252,250,244)),
    # OG. The rosette field in one pink on another -- the parts-built `spots`
    # pattern's grown-up sibling, and the reason the petal ring matters: a
    # flat disc would just be Bubblegum with dots.
    'spotty': dict(name='Spotty', parent='leopard', base=(250,178,198), ink=(176,52,96), fill=(214,92,136), nose=(226,120,152), ear=(255,206,222), pale=(255,232,240)),
    # OG. Stitched fabric panels, and the seams ARE the giraffe's lanes --
    # that generator draws flat cells separated by gaps, which is a patchwork
    # toy read as cloth rather than as an animal. `ink` is the panel and
    # `base` is the gap, so the pale oatmeal is the THREAD showing between
    # faded terracotta patches. Muted on purpose: saturation is what says
    # "animal", and washed-out cloth is what says "sewn". It also has to sit
    # beside Honeycomb (brown/gold) and Piggy Bank (cream/cobalt) on the same
    # parent without reading as a third of either.
    # The tweaks are the coat, as much as the palette is. `GAP HERE` is the
    # seam HALF-WIDTH: the patch mask is GREATER_THAN(distance-to-edge, it),
    # so the lane is twice this wide. The parent randomises it per cell
    # (0.060..0.136) and wanders it by +-0.038, which is a giraffe. A flat
    # 0.030 with a hair of grain left in is thread -- even, thin, and not so
    # sterile it reads as a CAD line. And the SCALE goes DOWN, not up: the
    # first retune took it to 1.55x for "more pieces" and rendered as
    # crackle glaze, because many small cells read as a texture. A sewn toy
    # is a few LARGE pattern pieces, so 0.70x is what says cloth -- and it
    # is the read at pedestal range that decides, where fine cells are noise
    # and a big panel with a seam across it is still a big panel.
    'patched': dict(name='Patched', parent='giraffe', base=(238,226,205), ink=(176,106,94), nose=(198,150,140), ear=(216,176,166), pale=(247,240,226),
        tweaks=[("this cell's own gap", 'To Min', 0.030), ("this cell's own gap", 'To Max', 0.030),
                ('wander amount', 1, 0.006), ('grain amount', 1, 0.004),
                ('finer over the face', 'To Min', 2.30), ('finer over the face', 'To Max', 1.75)]),
}
