"""Readable asset folders; saved-game IDs stay stable; asset filenames match the folders."""
HOUSE_FOLDERS = {
    'shack': 'cardboard-fort', 'cottage': 'beehive-cottage',
    'townhouse': 'wonky-townhouse', 'mushroom': 'toadstool-cottage',
    'villa': 'fairy-lantern-cottage', 'treehouse': 'treehouse',
    'manor': 'haunted-manor', 'slime': 'gloop-house', 'modern': 'fishbowl-house',
    'neontower': 'neon-tower', 'crystal': 'crystal-spire', 'palace': 'ice-palace',
    'skycastle': 'sky-castle', 'galleon': 'beached-galleon', 'portal': 'portal-house',
    'thundercloud': 'thundercloud-fortress', 'void': 'the-void',
    'goldenpig': 'golden-piggy', 'candy': 'gingerbread-manor-seasonal',
}


def house_slug(stable_id):
    """Accept an existing stable ID or its readable asset folder name."""
    return HOUSE_FOLDERS.get(stable_id, stable_id)
