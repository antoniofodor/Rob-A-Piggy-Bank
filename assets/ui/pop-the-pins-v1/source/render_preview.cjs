// Renders the HTML layout using the actual PNG files. Does not modify the sprites.
const { chromium } = require('C:/Users/anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const path = require('path');
const { pathToFileURL } = require('url');
(async()=>{
 const root=path.resolve(__dirname,'..');
 const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
 const page=await browser.newPage({viewport:{width:1120,height:720},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(pathToFileURL(path.join(root,'preview.html')).href+'?photo');
 await page.waitForLoadState('networkidle');
 await page.screenshot({path:path.join(root,'assembled-preview.png'),fullPage:true});
 await page.goto(pathToFileURL(path.join(root,'preview.html')).href);
 await page.waitForLoadState('networkidle');
 await page.screenshot({path:path.join(root,'asset-sheet-preview.png'),fullPage:true});
 await page.locator('#scrub').fill('100');
 const pinTop=await page.locator('.piece').evaluateAll(es=>es.find(e=>e.querySelector('image')?.getAttribute('href')?.endsWith('pin-active.png')).style.top);
 if(pinTop!=='48%')throw Error('Pin position preview failed: '+pinTop);
 await page.locator('#compact').check();
 await page.locator('#backdrop').click();
 await page.locator('#stage').screenshot({path:path.join(root,'compact-preview.png')});
 await page.setViewportSize({width:390,height:844});
 const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
 if(errors.length||overflow)throw Error(JSON.stringify({errors,overflow}));
 console.log('Rendered assembled, asset-sheet and compact previews. Slider and 390px page overflow checks passed.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
