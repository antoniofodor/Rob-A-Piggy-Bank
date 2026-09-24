"""Upload the approved hexagonal Honeycomb coat, honey-drop tail, and shop card."""
import json
import upload_spectral as uploader
ROOT=uploader.ROOT
HOME=ROOT/'assets/piggies/rare/honeycomb'
uploader.KEYS=['honeycomb']
def inputs(key):
 report=json.loads((HOME/'package/honeycomb-asset-report.json').read_text())
 assert report['fbxRoundTripMaxBoundsError']<.001 and report['tailRevision']['roundTripPassed']
 assets=[]
 for group in ('body','trim'):
  path=HOME/f'sheets/honeycomb_{group}_color.png'
  expected=next(t['sha256'] for t in report['textures'] if t['group']==group)
  assert uploader.sha(path)==expected
  assets.append((group+'_color',path,'Image','image/png'))
 tail=HOME/'package/honeycomb-tail.fbx'
 assert uploader.sha(tail)==report['tailRevision']['sha256']
 assets.extend([('tail',tail,'Model','model/fbx'),('shop_card',HOME/'preview/honeycomb_shop-card.png','Image','image/png')])
 folder=HOME/'revisions/hexagonal-installed';folder.mkdir(parents=True,exist_ok=True)
 accessories=folder/'honeycomb-accessories.fbx'
 if accessories.exists():assets.append(('accessories',accessories,'Model','model/fbx'))
 return folder,assets
uploader.inputs=inputs
if __name__=='__main__':uploader.main()
