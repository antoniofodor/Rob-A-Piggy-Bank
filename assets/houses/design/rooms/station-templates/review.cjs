const {chromium}=require('C:/Users/anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {pathToFileURL}=require('url');
const path=require('path');
const fs=require('fs');
(async()=>{
  const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
  const page=await browser.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const results=[];
  for(const [name,width,height] of [['desktop',1440,1040],['phone',1180,546],['portrait',390,844]]){
    await page.setViewportSize({width,height});
    await page.goto(pathToFileURL(path.join(__dirname,'index.html')).href);
    await page.waitForFunction(()=>Array.from(document.images).every(i=>i.complete));
    const result=await page.evaluate(()=>({horizontalOverflow:document.documentElement.scrollWidth>innerWidth,brokenImages:[...document.images].filter(i=>!i.naturalWidth).length,plans:document.images.length,links:[...document.links].map(a=>a.getAttribute('href'))}));
    for(const link of result.links){if(!fs.existsSync(path.join(__dirname,link)))throw Error('Missing '+link);}
    if(result.horizontalOverflow||result.brokenImages||result.plans!==4)throw Error(JSON.stringify(result));
    await page.screenshot({path:path.join(__dirname,`review-${name}.png`),fullPage:true});
    results.push({name,width,height,...result});
  }
  await browser.close();
  if(errors.length)throw Error(errors.join('\n'));
  fs.writeFileSync(path.join(__dirname,'browser-checks.json'),JSON.stringify({results,errors},null,2));
  console.log(JSON.stringify({results,errors},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
