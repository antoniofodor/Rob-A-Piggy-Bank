import upload_spectral as uploader
uploader.KEYS=['rainbowtiger']
def inputs(key):
 folder=uploader.ROOT/'assets/piggies/legendary/rainbowtiger/revisions/tail-tip-v2'
 return folder,[('shop_card',folder/'rainbowtiger-shop-card.png','Image','image/png')]
uploader.inputs=inputs
if __name__=='__main__':uploader.main()
