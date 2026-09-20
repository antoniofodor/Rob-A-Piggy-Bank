// Visual review of the standalone prototype only. No game/source changes.
const {chromium}=require('C:/Users/anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const path=require('path');const fs=require('fs');const {pathToFileURL}=require('url');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 const reports=[];
 for(const [name,w,h] of [['desktop-1040',1440,1040],['phone-546',1180,546],['phone-361',749,361],['portrait',390,844]]){
  await page.setViewportSize({width:w,height:h});await page.goto(pathToFileURL(path.join(__dirname,'../ui/catalogue.html')).href);await page.waitForFunction(()=>Array.from(document.images).every(i=>i.complete));
  await page.screenshot({path:path.join(__dirname,name+'.png')});
  const result=await page.evaluate(()=>{
   const bad=[];for(const e of document.querySelectorAll('.name,.price,.action,.rarity')){
    const r=document.createRange();r.selectNodeContents(e);const a=r.getBoundingClientRect(),b=e.getBoundingClientRect();if(a.width>b.width+1||a.height>b.height+1)bad.push({text:e.textContent,actual:[a.width,a.height],available:[b.width,b.height]});
   }
   const grid=document.querySelector('.grid'),scroller=document.querySelector('.scroller'),card=document.querySelector('.card').getBoundingClientRect();
   return {cards:document.querySelectorAll('.card').length,states:[...new Set([...document.querySelectorAll('.card')].map(c=>c.dataset.state))],overflowingText:bad,bodyOverflow:document.body.scrollWidth>innerWidth,cardPixels:[card.width,card.height],listScreens:scroller.scrollHeight/scroller.clientHeight,brokenImages:[...document.images].filter(i=>!i.naturalWidth).map(i=>i.src)};
  });reports.push({name,viewport:[w,h],...result});
 }
 await page.setViewportSize({width:1180,height:546});await page.goto(pathToFileURL(path.join(__dirname,'../ui/catalogue.html')).href);
 await page.locator('[data-filter=owned]').click();const ownedCount=await page.locator('.card').count();
 await page.locator('[data-id=cottage]').click();const moved=await page.locator('[data-id=cottage]').getAttribute('data-state');
 await page.locator('[data-filter=affordable]').click();await page.locator('[data-id=gardenbungalow]').click();
 await page.locator('[data-filter=owned]').click();const bought=await page.locator('[data-id=gardenbungalow]').getAttribute('data-state');
 await page.locator('#reset').click();await page.locator('[data-id=celestialcitadel]').click();const capacityHint=await page.locator('.toast').innerText();
 await page.locator('#coins').selectOption('0');await page.locator('[data-filter=affordable]').click();const empty=await page.locator('.empty').count();
 const interactions={ownedCount,moved,bought,capacityHint,empty};
 const output={reports,interactions,errors};fs.writeFileSync(path.join(__dirname,'ui-report.json'),JSON.stringify(output,null,2));console.log(JSON.stringify(output,null,2));
 await page.setViewportSize({width:1440,height:1040});
 await page.goto(pathToFileURL(path.join(__dirname,'../index.html')).href);
 await page.evaluate(()=>{document.querySelectorAll('img').forEach(i=>i.loading='eager')});
 await page.waitForFunction(()=>Array.from(document.images).every(i=>i.complete));
 await page.locator('#exteriors').screenshot({path:path.join(__dirname,'exterior-gallery.png')});
 await page.screenshot({path:path.join(__dirname,'gallery.png'),fullPage:true});
 const galleryBroken=await page.evaluate(()=>[...document.images].filter(i=>!i.naturalWidth).map(i=>i.src));
 if(galleryBroken.length)throw new Error('Missing gallery images: '+galleryBroken.join(', '));
 await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1});
