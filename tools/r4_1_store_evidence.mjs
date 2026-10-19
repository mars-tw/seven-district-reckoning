// Actual exported gameplay; local-only server and headless hardware WebGL.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {parseArgs} from 'node:util';
const {values:args}=parseArgs({options:{
  'web-dir':{type:'string'},'playwright-module':{type:'string'},output:{type:'string'},only:{type:'string'},
}});
if(!args['web-dir']||!args['playwright-module']||!args.output) throw Error('Supply web-dir, playwright-module and output');
const {chromium}=createRequire(import.meta.url)(args['playwright-module']);
const directory=path.resolve(args['web-dir']), output=path.resolve(args.output);
fs.mkdirSync(output,{recursive:true});
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const gpuArgs=['--use-angle=d3d11','--enable-gpu','--ignore-gpu-blocklist','--force_high_performance_gpu'];
const server=http.createServer((req,res)=>{
  let name;
  try {name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);} catch {res.writeHead(400).end();return;}
  if(name.endsWith('/')) name+='index.html';
  const wasm=name==='/game.wasm', file=path.resolve(directory,'.'+name+(wasm?'.br':''));
  if(!file.startsWith(directory+path.sep)||!fs.existsSync(file)){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',wasm?'application/wasm':({'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png'})[path.extname(file)]||'application/octet-stream');
  if(wasm)res.setHeader('Content-Encoding','br');
  fs.createReadStream(file).pipe(res);
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin=`http://127.0.0.1:${server.address().port}`;
const manifest={status:'EXECUTED',version:'0.8.1',base_commit:'41c78c4',
  environment:'並發載量測，僅供參考',
  method:'Unedited screenshots of the actual Godot 4.7 stable Web export; headless Chromium, ANGLE D3D11 hardware WebGL. No compositing, generated substitute or screenshot resizing. These are browser captures, not native iOS device captures.',
  chromium_args:gpuArgs,image_model_slug:null,pck_sha256:hash(path.join(directory,'game.pck')),views:[],failures:[]};
let browser;
const assert=(ok,message)=>{if(!ok)throw Error(message);};
try {
  browser=await chromium.launch({headless:true,args:gpuArgs});
  manifest.chromium_version=browser.version();
  const matrix=[[430,932,3,'phone'],[1032,1376,2,'tablet'],[430,932,1,'phone'],[390,844,1,'phone'],[1376,1032,1,'tablet']];
  for(const [width,height,dpr,profile] of matrix){
    const tag=`${width*dpr}x${height*dpr}`;
    if(args.only&&args.only!==tag)continue;
    console.log(`CAPTURE ${tag}`);
    const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:dpr,hasTouch:true,isMobile:true});
    const page=await context.newPage();
    page.setDefaultTimeout(90000);
    const view={viewport:{width,height},device_scale_factor:dpr,pixels:{width:width*dpr,height:height*dpr},profile,logs:[],blocked_remote_origins:[],shots:[],reopen_checks:[]};
    manifest.views.push(view);
    page.on('console',msg=>{if(msg.type()==='error')view.logs.push(msg.text());});
    page.on('pageerror',e=>view.logs.push(e.message));
    await context.route('**/*',route=>{
      const u=new URL(route.request().url());
      if(!['http:','https:'].includes(u.protocol)||u.origin===origin)return route.continue();
      view.blocked_remote_origins.push(u.origin);return route.abort();
    });
    const state=()=>page.evaluate(()=>JSON.parse(JSON.stringify(window.sevenDistrictGame)));
    const healthy=async()=>{
      const s=await state();
      view.last_layout=s.layout;
      assert(s.version==='0.8.1','Capture source version mismatch');
      assert(s.layout,'Missing Web layout diagnostics');
      assert(s.layout.peak_sorts_per_frame<=32,'Unbounded container layout');
      assert(!view.logs.length&&!view.blocked_remote_origins.length,'Browser error or remote request');
      return s;
    };
    const shot=async name=>{
      await page.waitForTimeout(1200);
      const s=await healthy(), file=`${tag}-${name}.png`;
      await page.screenshot({path:path.join(output,file)});
      view.shots.push({file,sha256:hash(path.join(output,file)),state:s});
      console.log('SHOT',file);
    };
    try {
      await page.goto(`${origin}/${profile}/`);
      await page.locator('#start-button').click();
      await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title');
      await page.locator('#fullscreen-button').click();
      await page.waitForTimeout(1800);
      view.canvas=await page.locator('#canvas').boundingBox();
      assert(view.canvas.width===width&&view.canvas.height===height,'Canvas must fill requested CSS viewport');
      view.game_renderer=await page.evaluate(()=>{
        const c=document.querySelector('#canvas'),g=c.getContext('webgl2')||c.getContext('webgl');
        const e=g.getExtension('WEBGL_debug_renderer_info');return e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER);
      });
      assert(/NVIDIA/.test(view.game_renderer)&&!/SwiftShader|llvmpipe/i.test(view.game_renderer),'Hardware NVIDIA renderer required');
      await shot('title');
      await page.evaluate(()=>window.sevenDistrictCommand('new_game'));
      await page.waitForTimeout(1600);
      await shot('dialogue');
      for(let i=0;i<3;i++){await page.keyboard.press('Enter');await page.waitForTimeout(500);}
      await page.waitForTimeout(1500);
      await shot('dialogue-meiqing');
      await page.keyboard.press('Enter');
      await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='playing'&&window.sevenDistrictGame?.case_stage===1);
      await page.waitForFunction(()=>window.sevenDistrictGame?.world_ready);
      await page.waitForTimeout(1200);
      // Capture the visible caption, including its true fade state.
      await shot('street');
      await page.locator('#canvas').focus();
      await page.keyboard.down('w');
      try {await page.waitForFunction(()=>Math.hypot(window.sevenDistrictGame.player_x+52,window.sevenDistrictGame.player_z-57)<2.5,null,{timeout:30000});}
      finally {await page.keyboard.up('w');}
      await page.waitForTimeout(300);
      const before=(await state()).layout;
      await page.keyboard.press('e');
      await page.waitForFunction(()=>window.sevenDistrictGame?.case_stage===2&&window.sevenDistrictGame?.menu==='case',null,{timeout:20000});
      await shot('evidence');
      const after=(await healthy()).layout;
      assert(after.resize_calls-before.resize_calls<=4&&after.container_sorts-before.container_sorts<=24,'Witness open must converge within a bounded number of deferred calls');
      assert(after.case_gutter_reserved,'Case needs a stable text wrapping width');
      if(profile==='tablet') assert(after.panel[2]>=width*.80,'Tablet case is too narrow');
      view.witness_open_delta={resize:after.resize_calls-before.resize_calls,sorts:after.container_sorts-before.container_sorts};
      // Reopen through the same public UI command used by the website toolbar.
      for(let i=0;i<3;i++){
        await page.evaluate(()=>window.sevenDistrictCommand('resume'));
        await page.waitForFunction(()=>window.sevenDistrictGame?.menu==='');
        const a=(await state()).layout;
        await page.evaluate(()=>window.sevenDistrictCommand('case'));
        await page.waitForFunction(()=>window.sevenDistrictGame?.menu==='case');
        await page.waitForTimeout(650);
        const b=(await healthy()).layout;
        assert(b.resize_calls-a.resize_calls<=4&&b.container_sorts-a.container_sorts<=24,'Repeated open failed to converge');
        const c=(await state()).layout;
        await page.waitForTimeout(650);
        assert((await state()).layout.container_sorts===c.container_sorts,'Case continues reflowing while idle');
        view.reopen_checks.push({resize:b.resize_calls-a.resize_calls,sorts:b.container_sorts-a.container_sorts,stable:true});
      }
      await page.keyboard.press('Enter');
      await shot('link');
      await page.keyboard.press('Enter');
      await page.waitForFunction(()=>window.sevenDistrictGame?.case_stage===3);
      await page.keyboard.press('Enter');
      await page.waitForFunction(()=>window.sevenDistrictGame?.case_stage===4);
      await shot('sealed');
      view.final_state=await healthy();
    } catch(error){
      manifest.failures.push({tag,error:String(error.message||error)});
      console.error('FAIL',tag,error.message);
    } finally {
      await context.close();
      fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
    }
  }
  assert(manifest.views.length>0,'No matching view');
  assert(!manifest.failures.length,'Capture or layout regression failed');
  manifest.status='VERIFIED';
} finally {
  fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  if(browser)await browser.close();
  server.closeAllConnections();
  await new Promise(resolve=>server.close(resolve));
}
