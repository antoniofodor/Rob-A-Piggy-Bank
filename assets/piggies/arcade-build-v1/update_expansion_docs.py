"""Refresh gallery wording for the expanded pack, keeping the original four assets intact."""
from pathlib import Path
HERE=Path(__file__).resolve().parent
p=HERE/'finalize.py';text=p.read_text(encoding='utf-8')
for a,b in [
 ('Validate all four assets','Validate all Arcade assets'),
 ("'count':4", "'count':len(rows)"),
 ('# Arcade — four starter builds','# Arcade — expanded collection'),
 ('Player One (Rare), Retro Carpet (Rare), Respawn (Epic), Jackpot (Legendary).','Ten completed local assets: four Rares, three Epics and three Legendaries. This expansion adds Pixel, Circuit Board, Power-Up, Synthwave, Final Boss and Mecha Player.'),
 ('arcade-collection-v1.blend','arcade-collection-v2.blend'),
 ('overview plus four individual asset scenes','overview plus ten individual asset scenes'),
 ('Arcade Piggies · First Four','Arcade Piggies · Expanded Collection'),
 ('Four starter piggies, built from the selected concepts.','Ten piggies, including six new Arcade designs.'),
 ('--keys playerone,retrocarpet,respawn,jackpot','--keys playerone,retrocarpet,respawn,jackpot,pixel,circuitboard,powerup,synthwave,finalboss,mechaplayer'),
 ]:text=text.replace(a,b)
p.write_text(text,encoding='utf-8')
show=(HERE/'show_collection_mcp.py').read_text().replace('arcade-collection-v1.blend','arcade-collection-v2.blend').replace("s.name.startswith('ARCADE - four starter builds')","s.name.startswith('ARCADE - expanded collection')")
(HERE/'show_collection_mcp.py').write_text(show,encoding='utf-8')
