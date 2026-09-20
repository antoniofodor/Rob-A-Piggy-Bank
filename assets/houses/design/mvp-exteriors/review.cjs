const {chromium}=require('C:/Users/anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {pathToFileURL}=require('url');const path=require('path');const fs=require('fs');
const assert=(ok,msg)=>{if(!ok)throw Error(msg)};
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 const url=pathToFileURL(path.join(__dirname,'catalogue.html')).href;
 const reports=[];
 for(const [name,width,height] of [['desktop',1440,1040],['phone',1180,546],['portrait',390,844]]){
  await page.setViewportSize({width,height});await page.goto(url);
  const r=await page.evaluate(()=>{
   const overflowing=[];for(const e of document.querySelectorAll('.name,.price,.action')){const range=document.createRange();range.selectNodeContents(e);const a=range.getBoundingClientRect(),b=e.getBoundingClientRect();if(a.width>b.width+1||a.height>b.height+1)overflowing.push(e.textContent)}
   const s=document.querySelector('.scroller');const c=document.querySelector('.card').getBoundingClientRect();
   return {cards:document.querySelectorAll('.card').length,states:[...new Set([...document.querySelectorAll('.card')].map(e=>e.dataset.state))],overflowing,horizontalOverflow:document.documentElement.scrollWidth>innerWidth,cardSize:[c.width,c.height],catalogueScreens:s.scrollHeight/s.clientHeight};
  });
  assert(r.cards===19&&!r.overflowing.length&&!r.horizontalOverflow,'Layout '+name+JSON.stringify(r));
  await page.screenshot({path:path.join(__dirname,`catalogue-${name}.png`)});
  await page.locator('[data-id=thundercloud]').click();
  await page.waitForFunction(()=>[...document.images].every(i=>i.complete));
  const detail=await page.evaluate(()=>{const p=document.querySelector('.purchase').getBoundingClientRect();const b=document.querySelector('.primary').getBoundingClientRect();return {actionVisible:p.bottom<=innerHeight&&p.top>=0,actionHeight:b.height,brokenImages:[...document.images].filter(i=>!i.naturalWidth).length}});
  assert(detail.actionVisible&&detail.actionHeight>=48&&!detail.brokenImages,'Detail layout '+name);
  await page.screenshot({path:path.join(__dirname,`detail-${name}.png`)});
  reports.push({name,width,height,...r,detail});
 }
 await page.setViewportSize({width:1180,height:546});await page.goto(url);
 const before=await page.evaluate(()=>({coins,shown,count:owned.size}));
 await page.locator('[data-id=mushroom]').click();
 const afterSelect=await page.evaluate(()=>({coins,shown,count:owned.size}));assert(JSON.stringify(before)===JSON.stringify(afterSelect),'Selection must not spend');
 await page.locator('.primary').click();assert(await page.evaluate(()=>coins===2250000&&owned.has('mushroom')&&shown==='mushroom'),'Explicit buy');
 await page.locator('.back').click();await page.locator('[data-id=cottage]').click();await page.locator('.primary').click();assert(await page.evaluate(()=>coins===2250000&&shown==='cottage'),'Move in must not spend');
 await page.locator('.back').click();await page.locator('#capacity').selectOption('500000');
 assert(await page.locator('[data-id=villa]').getAttribute('data-state')==='owned','Owned priority');
 await page.locator('[data-id=goldenpig]').click();assert(await page.locator('.primary').isDisabled(),'Earned goal cannot be bought');assert((await page.locator('#detail-price').innerText())==='EARNED HOME','Earned is not free');await page.locator('.back').click();
 await page.locator('#reset').click();const ids=await page.locator('[data-id]').evaluateAll(es=>es.map(e=>e.dataset.id));await page.locator('#coins').selectOption('0');
 assert(JSON.stringify(ids)===JSON.stringify(await page.locator('[data-id]').evaluateAll(es=>es.map(e=>e.dataset.id))),'Stable order');
 await page.locator('[data-filter=affordable]').click();assert(await page.locator('.empty').count()===1,'Empty affordable');
 await page.locator('#reset').click();await page.evaluate(()=>{owned=new Set(houses.filter(h=>h.cost!==null).map(h=>h.id));owned.add('goldenpig');capacity=1;coins=0;render()});
 await page.locator('[data-id=goldenpig]').click();assert(await page.locator('.primary').isEnabled(),'Owned earned home usable');await page.locator('.primary').click();assert(await page.evaluate(()=>shown==='goldenpig'&&coins===0),'Earned move in');await page.locator('.back').click();
 // Verify every reference image, not only ones opened in screenshots.
 const images=await page.evaluate(()=>Object.values(art));for(const image of images)assert(fs.existsSync(path.resolve(__dirname,image)),'Missing reference '+image);
 await page.goto(pathToFileURL(path.join(__dirname,'index.html')).href);await page.setViewportSize({width:1440,height:1040});await page.waitForFunction(()=>[...document.images].every(i=>i.complete));
 for(const link of await page.locator('a').evaluateAll(es=>es.map(e=>e.getAttribute('href'))))assert(fs.existsSync(path.resolve(__dirname,link)),'Broken gallery link '+link);
 assert(await page.evaluate(()=>[...document.images].every(i=>i.naturalWidth)),'Gallery images');await page.screenshot({path:path.join(__dirname,'gallery-desktop.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Gallery mobile overflow');await page.screenshot({path:path.join(__dirname,'gallery-phone.png'),fullPage:true});
 assert(!errors.length,errors.join('\n'));await browser.close();
 const result={reports,interactionChecks:['selection does not spend','explicit buy','free move in','owned priority','earned not purchasable','stable order','empty affordable','owned earned move in'],referenceImages:images.length,errors};
 fs.writeFileSync(path.join(__dirname,'browser-checks.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
