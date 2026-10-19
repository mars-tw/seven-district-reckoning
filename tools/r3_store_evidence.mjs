// Actual Godot WebGL screenshots, headless Chromium only. No substitute artwork.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const args=Object.fromEntries(process.argv.slice(2).reduce((a,v,i,all)=>i%2?a:[...a,[v.slice(2),all[i+1]]],[]));
if(!args['web-dir']||!args['playwright-module']) throw Error('Explicit local web-dir and installed playwright-module are required');
const {chromium}=createRequire(import.meta.url)(args['playwright-module']);
const directory=path.resolve(args['web-dir']);
const output=path.resolve(args.output||'docs/store/screenshots');
fs.mkdirSync(output,{recursive:true});
const server=http.createServer((req,res)=>{
  let name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(name.endsWith('/')) name+='index.html';
  const wasm=name==='/game.wasm';
  const file=path.resolve(directory,'.'+name+(wasm?'.br':''));
  if(!file.startsWith(directory+path.sep)||!fs.existsSync(file)){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',wasm?'application/wasm':({'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png'})[path.extname(file)]||'application/octet-stream');
  if(wasm)res.setHeader('Content-Encoding','br');
  fs.createReadStream(file).pipe(res);
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin=`http://127.0.0.1:${server.address().port}`;
const manifest={status:'EXECUTED',version:'0.7.0',environment:'並發載量測，僅供參考',
  lifecycle_enabled:args.matrix!=='small'&&args.lifecycle!=='off',
  method:'Actual exported Godot WebGL canvas; unedited browser screenshots, no image generation or screenshot resizing; not iOS device captures',
  image_model_slug:null,pck_sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(directory,'game.pck'))).digest('hex'),views:[]};
let browser;
try{
  browser=await chromium.launch({headless:true,executablePath:args['chromium-executable']||chromium.executablePath(),args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
  const matrix=args.matrix==='small'?[[375,667,1,'phone'],[667,375,1,'phone'],[1366,600,1,'desktop']]:[[430,932,3,'phone'],[1032,1376,2,'tablet']];
  for(const [width,height,dpr,profile] of matrix){
    console.log(`CAPTURE ${width*dpr}x${height*dpr}`);
    const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:dpr,hasTouch:true,isMobile:true});
    const page=await context.newPage();
    page.setDefaultTimeout(180000);
    const logs=[],blocked=[],requests=[];
    page.on('console',msg=>{if(msg.type()==='error')logs.push(msg.text());});
    page.on('pageerror',e=>logs.push(e.message));
    await context.route('**/*',route=>{
      const u=new URL(route.request().url());
      if(!['http:','https:'].includes(u.protocol)||u.origin===origin){requests.push(u.pathname);return route.continue();}
      blocked.push(u.origin);return route.abort();
    });
    await page.goto(`${origin}/${profile}/`);
    await page.locator('#start-button').click();
    await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title');
    await page.locator('#fullscreen-button').click();
    await page.waitForTimeout(1500);
    const canvas=await page.locator('#canvas').boundingBox();
    if(Math.abs(canvas.width-width)>2||Math.abs(canvas.height-height)>2)throw Error('Canvas does not fill viewport');
    const view={viewport:{width,height},device_scale_factor:dpr,pixels:{width:width*dpr,height:height*dpr},logs,blocked_remote_origins:blocked,shots:[]};
    const shot=async name=>{
      const filename=`${width*dpr}x${height*dpr}-${name}.png`;
      const file=path.join(output,filename);
      await page.screenshot({path:file});
      view.shots.push({file:filename,sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),state:await page.evaluate(()=>({...window.sevenDistrictGame}))});
    };
    await shot('title');
    const start=Date.now();
    await page.evaluate(()=>window.sevenDistrictCommand('new_game'));
    await page.waitForTimeout(1200);
    await page.mouse.click(width-64,40);
    await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='playing'&&window.sevenDistrictGame?.case_stage===1);
    await page.waitForTimeout(5000);
    await shot('street');
    // Walk toward the shop with the real keyboard action and physics.
    await page.locator('#canvas').focus();
    await page.keyboard.down('w');
    try{await page.waitForFunction(()=>Math.hypot(window.sevenDistrictGame.player_x+52,window.sevenDistrictGame.player_z-57)<2.5,{},{timeout:45000});}
    finally{await page.keyboard.up('w');}
    await page.waitForTimeout(500);
    await page.keyboard.press('e');
    await page.waitForFunction(()=>window.sevenDistrictGame?.case_stage===2&&window.sevenDistrictGame?.menu==='case');
    await page.waitForTimeout(800);
    await shot('evidence');
    view.seconds_to_physical_witness=(Date.now()-start)/1000;
    await page.keyboard.press('Enter'); // Focused first claim, then first proof.
    await page.waitForTimeout(600);
    await shot('link');
    await page.keyboard.press('Enter');
    await page.waitForFunction(()=>window.sevenDistrictGame?.case_stage===3);
    await page.keyboard.press('Enter');
    await page.waitForFunction(()=>window.sevenDistrictGame?.case_stage===4);
    await page.waitForTimeout(600);
    await shot('sealed');
    view.seconds_to_sealed_case=(Date.now()-start)/1000;
    console.log(`SEALED ${profile} ${view.seconds_to_sealed_case}s`);
    // Real browser-process lifecycle: destroy this WASM instance, reopen/load
    // the saved campaign, then read the sealed case again from its public menu.
    if(manifest.lifecycle_enabled){
    await page.waitForTimeout(6000); // Allow the engine's IndexedDB sync.
    await page.reload();
    await page.locator('#start-button').click();
    await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title');
    await page.locator('#fullscreen-button').click();
    await page.waitForFunction(()=>window.sevenDistrictGame?.world_ready,{},{timeout:240000});
    await page.evaluate(()=>window.sevenDistrictCommand('load'));
    await page.waitForTimeout(1500);
    view.relaunch_state=await page.evaluate(()=>({...window.sevenDistrictGame}));
    if(!view.relaunch_state.play_started||view.relaunch_state.case_stage!==4){
      manifest.views.push(view);
      throw Error('Browser relaunch did not restore sealed case: '+JSON.stringify(view.relaunch_state));
    }
    await page.evaluate(()=>window.sevenDistrictCommand('case'));
    await page.waitForFunction(()=>window.sevenDistrictGame?.menu==='case');
    view.relaunch_preserved_case=true;
    console.log(`RELAUNCH VERIFIED ${profile}`);
    }
    view.request_paths=[...new Set(requests)].sort();
    if(logs.length||blocked.length)throw Error('Browser errors or attempted remote requests: '+JSON.stringify({logs,blocked}));
    manifest.views.push(view);
    fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
    await context.close();
  }
  manifest.status='VERIFIED';
}finally{
  fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  if(browser)await browser.close();
  await new Promise(resolve=>server.close(resolve));
}
