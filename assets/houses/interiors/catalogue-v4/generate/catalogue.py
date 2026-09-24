"""Permanent catalogue IDs, palettes and architectural families. Dimensions are studs."""
def theme(id, title, style, colors, description):
    keys='wall roof trim floor top accent glass door'.split()
    palette={key:list(bytes.fromhex(value)) for key,value in zip(keys,colors.split())}
    palette.update(wood=palette['trim'],cream=[243,229,199],metal=[78,83,90],
        gold=[222,171,67],pink=[223,147,167],leaf=[88,139,74],sky=[164,211,221],
        referenceSkin=[215,205,180],referenceThief=[49,65,84],referenceOwner=[163,65,64])
    return dict(id=id,title=title,style=style,palette=palette,description=description,
        kit=''.join(title.split())+'InteriorKit')

CATALOGUE={
 'wonky-townhouse':theme('townhouse','Wonky Townhouse','town',
    'eee1c4 d3d9d0 476a73 c4b096 c7d9d3 d4826f b4d3db 527e8d',
    'Crooked teal and terracotta wall bays, mismatched windows and offset rafters above a level floor.'),
 'toadstool-cottage':theme('mushroom','Toadstool Cottage','mushroom',
    'ede4c9 c78383 70503d cfc2a2 a3b476 b04c5c e6c47a 876247',
    'Cream stalk walls, a spotted red cap vault, curved timber ribs and mushroom-rimmed stumps.'),
 'fairy-lantern-cottage':theme('villa','Fairy Lantern Cottage','fairy',
    'e3e7cb d3dfb5 557543 c9c8a6 b8ce91 d7b56d badcd6 66834e',
    'Leaf brackets, hanging colored lanterns, climbing vines and green cottage joinery.'),
 'haunted-manor':theme('manor','Haunted Manor','haunted',
    '9e9cac c2bbd4 62536c 9994a5 b9adcb a18cc6 e0c9a3 73627e',
    'Pointed windows, purple wall panels, high gothic ribs and violet candle sconces.'),
 'gloop-house':theme('slime','Gloop House','gloop',
    'c8df9a acd686 448757 c1d197 d4eb9c 8eba57 e9d88c ca8949',
    'Rounded slime bands, hanging drips and orange mechanical-looking doors in a bright lime room.'),
 'fishbowl-house':theme('modern','Fishbowl House','aquarium',
    'd7ebe4 b8dcde 51919d c7dddd e7ede2 81b7b4 619cae 78aeb6',
    'Dry pearl floors under aquarium vaults; large portholes show stylized fish, bubbles and kelp.'),
 'neon-tower':theme('neontower','Neon Tower','neon',
    '798b9b a3b4bf 34495b 7f929f b4d6dc 64c5cc 314d66 466071',
    'Steel ceiling cassettes, city-window panels, cyan conduits and restrained magenta accents.'),
 'crystal-spire':theme('crystal','Crystal Spire','crystal',
    'b3a6c9 d9cdec 635378 a2a0b8 d6c6ec a484cc 8973b4 796195',
    'Angular geode ribs, split diamond windows, crystal sconces and faceted amethyst plinths.'),
 'ice-palace':theme('palace','Ice Palace','ice',
    'dce9ef e5f0f5 8aaabd c7dbe4 e8f5f4 9bcadd b4dce9 9abccc',
    'Pale frozen arches, frost tracery, overhead icicles and low diamond-shaped ice plinths.'),
 'sky-castle':theme('skycastle','Sky Castle','sky',
    'e6e6e7 e8e7f0 a195b9 d5d4df eae7f2 b8a2d1 a4c9e0 ac9abe',
    'White castle piers, arched sky windows, cloud crests and lavender royal doors.'),
 'beached-galleon':theme('galleon','Beached Galleon','ship',
    'b99773 c6ad89 73523b b39776 cab796 c9a568 95bfcb 876347',
    'Broad timber hull ribs, deck planks, brass portholes, rope trim and cargo-crate pedestals.'),
 'portal-house':theme('portal','Portal House','portal',
    'c2d3d4 c8cde1 6a648e aebbc9 c9dbe1 769cad 9d92c0 728d9e',
    'A familiar house split between teal and violet, with offset angular ribs and portal window rings.'),
 'thundercloud-fortress':theme('thundercloud','Thundercloud Fortress','storm',
    '929eb1 b5c0ce 53677e 98a6b7 c3cddb aacbdf 6d85a1 647c98',
    'Stepped fortress piers, slate masonry, cloud bands and pale lightning inlays.'),
 'the-void':theme('void','The Void','void',
    '626575 77798e 353848 737787 a0a3b9 9c8ac7 414252 535468',
    'Readable charcoal planes, black angular ribs, star recesses and fine violet boundaries.'),
 'golden-piggy':theme('goldenpig','Golden Piggy','gold',
    'f0e1b7 eddba6 b69247 d8c59c f1dfa6 d4b365 e6ceb0 c2a054',
    'Cream and gold barrel vaults, coin coffers, piggy crests and round gold-edged display bases.'),
}

# Retain the three approved designs, now sized by their catalogue rank too.
EXISTING={
 'cardboard-fort':dict(id='shack',title='Cardboard Fort',kit='CardboardFortInteriorKit',description='Approved cardboard panels, tape seams and carton bases.'),
 'beehive-cottage':dict(id='cottage',title='Beehive Cottage',kit='BeehiveCottageInteriorKit',description='Approved honey vault, hexagonal windows and honeycomb bases.'),
 'treehouse':dict(id='treehouse',title='Treehouse',kit='TreehouseInteriorKit',description='Approved branch trusses, round forest windows and stump bases.'),
}
CATALOGUE.update(EXISTING)
