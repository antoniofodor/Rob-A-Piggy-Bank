"""The eight designer-approved revisions requested for Studio installation."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
HERE = ROOT/'assets/piggies/approved-imports-20260923'
SPECS = []
for key in ('aurora', 'banker', 'rockslide', 'quartz', 'neonmint'):
    home = ROOT/'assets/piggies/rare'/key/'revisions/og-v2'
    SPECS.append(dict(key=key, tier='rare', revision='og-v2', home=home,
                     package=home/'package', report=home/'package/og-v2-asset-report.json',
                     blend=home/'package'/f'{key}-og-v2.blend'))
for key, revision in [('mechaplayer','arcade-v4'),('finalboss','spellcaster-v5'),('jackpot','jackpot-v3')]:
    home = ROOT/'assets/piggies/legendary'/key
    package = home/'package'/revision
    SPECS.append(dict(key=key, tier='legendary', revision=revision, home=home,
                     package=package, report=package/'asset-report.json',
                     blend=package/f'{key}-{revision}.blend'))

def report(spec):
    return json.loads(spec['report'].read_text())

def receipt_path(spec):
    return HERE/(spec['key']+'-uploads.json')
