// Actual exported gameplay; local-only server and headless hardware WebGL.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {parseArgs} from 'node:util';
const {values:args}=parseArgs({options:{
  'web-dir':{type:'string'},'playwright-module':{type:'string'},output:{type:'string'},version:{type:'string',default:'0.13.0'},only:{type:'string'},
  'perf-only':{type:'boolean',default:false},'street-only':{type:'boolean',default:false},'skip-perf':{type:'boolean',default:false},
  'clock-seal':{type:'boolean',default:false},
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
const manifest={status:'EXECUTED',version:args.version,base_commit:'R9-local-candidate',
  environment:'並發載量測，僅供參考',
  method:'Unedited screenshots of the actual Godot 4.7 stable Web export; headless Chromium, ANGLE D3D11 hardware WebGL. No compositing, generated substitute or screenshot resizing. These are browser captures, not native iOS device captures.',
  chromium_args:gpuArgs,image_model_slug:null,pck_sha256:hash(path.join(directory,'game.pck')),views:[],failures:[]};
let browser;
const assert=(ok,message)=>{if(!ok)throw Error(message);};
try {
  browser=await chromium.launch({headless:true,args:gpuArgs});
  manifest.chromium_version=browser.version();
  const matrix=[[390,844,1,'phone'],[430,932,3,'phone'],[1032,1376,2,'tablet'],[844,390,1,'phone'],[320,568,1,'phone'],[768,1024,1,'tablet'],[1024,768,1,'tablet'],[1366,600,1,'desktop'],[1366,768,1,'desktop'],[1920,1080,1,'desktop']];
  for(const [width,height,dpr,profile] of matrix){
    const tag=`${width*dpr}x${height*dpr}`;
    if(args.only&&args.only!==tag)continue;
    console.log(`CAPTURE ${tag}`);
    const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:dpr,hasTouch:true,isMobile:true});
    const page=await context.newPage();
    page.setDefaultTimeout(90000);
    const controlledStore=['1290x2796','2064x2752'].includes(tag);
    if(args['clock-seal']||controlledStore)await page.clock.install();
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
      assert(s.version===args.version,'Capture source version mismatch');
      assert(s.layout,'Missing Web layout diagnostics');
      assert(s.layout.peak_sorts_per_frame<=32,'Unbounded container layout');
      assert(!view.logs.length&&!view.blocked_remote_origins.length,'Browser error or remote request');
      return s;
    };
    const shot=async name=>{
      await page.waitForTimeout(800);
      const s=await healthy();
      if(args['clock-seal']){(view.clock_steps??=[]).push({name,state:s});return;}
      const file=`${tag}-${name}.png`;
      await page.screenshot({path:path.join(output,file)});
      view.shots.push({file,sha256:hash(path.join(output,file)),state:s});
      console.log('SHOT',file);
    };
    try {
      await page.goto(`${origin}/${profile}/`);
      await page.locator('#start-button').click();
      await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title');
      await page.locator('#fullscreen-button').click();
      await page.waitForTimeout(800);
      view.canvas=await page.locator('#canvas').boundingBox();
      assert(view.canvas.width===width&&view.canvas.height===height,'Canvas must fill requested CSS viewport');
      view.game_renderer=await page.evaluate(()=>{
        const c=document.querySelector('#canvas'),g=c.getContext('webgl2')||c.getContext('webgl');
        const e=g.getExtension('WEBGL_debug_renderer_info');return e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER);
      });
      assert(/NVIDIA/.test(view.game_renderer)&&!/SwiftShader|llvmpipe/i.test(view.game_renderer),'Hardware NVIDIA renderer required');
      await shot('title');
      await page.evaluate(()=>window.sevenDistrictCommand('new_game'));
      await page.waitForTimeout(700);
      await shot('dialogue');
      for(let i=0;i<3;i++){await page.keyboard.press('Enter');await page.waitForTimeout(350);}
      await page.waitForTimeout(700);
      await shot('dialogue-meiqing');
      await page.keyboard.press('Enter');
      await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='playing'&&window.sevenDistrictGame?.case_stage===1);
      await page.waitForFunction(()=>window.sevenDistrictGame?.world_ready);
      await page.waitForTimeout(1200);
      // Capture the visible caption, including its true fade state.
      if(args['street-only'])await page.waitForTimeout(7000);
      await page.waitForTimeout(4000);
      await shot('street');
      if(args['street-only']){view.street_capture_wait_ms=7000;view.final_state=await healthy();continue;}
      if(!args['skip-perf']&&['390x844','1366x768'].includes(tag)){
        const samples=[];
        for(let run=0;run<3;run++)samples.push(await page.evaluate(()=>new Promise(resolve=>{
          const values=[],counters=[];let prev=0;
          function tick(t){if(prev)values.push(t-prev);prev=t;const s=window.sevenDistrictGame;if(s)counters.push({process_ms:s.process_ms,physics_ms:s.physics_ms,draw_calls:s.draw_calls,primitives:s.render_primitives,resolution_scale:s.resolution_scale,fps:s.frame_fps});if(values.length<180)requestAnimationFrame(tick);else{values.sort((a,b)=>a-b);resolve({p50:values[89],p95:values[170],max:values.at(-1),frames:values.length,counters});}}
          requestAnimationFrame(tick);
        })));
        view.frame_pacing={method:'browser requestAnimationFrame presentation intervals, not native GPU timer; concurrent host load',runs:samples,p95_median:samples.map(x=>x.p95).sort((a,b)=>a-b)[1]};
      }
      if(args['perf-only']){view.final_state=await healthy();continue;}
      await page.locator('#canvas').focus();
      await page.keyboard.down('w');
      try {await page.waitForFunction(()=>Math.hypot(window.sevenDistrictGame.player_x+52,window.sevenDistrictGame.player_z-57)<2.5,null,{timeout:30000});}
      finally {await page.keyboard.up('w');}
      await page.waitForTimeout(300);
      const before=(await state()).layout;
      await page.keyboard.press('e');
      await page.waitForFunction(()=>window.sevenDistrictGame?.case_stage===2&&window.sevenDistrictGame?.menu==='case',null,{timeout:20000});
      await shot('evidence');
      view.inspections=[];
      for(const photo of (args['clock-seal']?[]:(await state()).art.details.photos)) {
        const [x,y,w,h]=photo.rect; await page.mouse.click(x+w/2,y+h/2);
        await page.waitForFunction(()=>Boolean(window.sevenDistrictGame?.art?.details?.inspection));
        const file=`${tag}-${photo.name==='InspectReceipt'?'receipt':'message'}-inspection.png`;
        await page.screenshot({path:path.join(output,file)});
        const inspected=await state();
        view.inspections.push({file,sha256:hash(path.join(output,file)),state:inspected});
        const [cx,cy,cw,ch]=inspected.art.details.inspection.close;
        await page.mouse.click(cx+cw/2,cy+ch/2);
        await page.waitForFunction(()=>window.sevenDistrictGame?.art?.details?.inspection===false);
      }

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
      if(args['clock-seal']||controlledStore) {
        // Pause the real browser animation clock at a known engine frame.
        // Every PNG is the actual Godot renderer; no compositing or state edits.
        await page.clock.pauseAt(await page.evaluate(()=>Date.now()+500));
        await page.keyboard.press('Enter');
        view.clock_seal=[];
        let elapsed=0;
        for(const [index,delta] of [[1,50],[2,80],[3,190]]) {
          await page.clock.runFor(delta);elapsed+=delta;
          const file=`${tag}-seal-controlled-${index}.png`;
          await page.screenshot({path:path.join(output,file),animations:'allow'});
          view.clock_seal.push({file,state:await healthy(),sha256:hash(path.join(output,file)),elapsed_ms:elapsed,method:'Actual Godot frame with browser clock stepped and paused; no image editing, injected art or game-state modification.'});
        }
        assert(new Set(view.clock_seal.map(x=>x.sha256)).size===3,'Stepped frames must visibly differ');
        await page.clock.resume();
        await page.waitForTimeout(1200);
        view.final_state=await healthy();
        assert(view.final_state.case_stage===4,'Stepped seal must reach the same real conclusion');
        if(args['clock-seal'])continue;
      }
      if(!controlledStore) {
        await page.keyboard.press('Enter');
        await page.waitForFunction(()=>window.sevenDistrictGame?.case_stage===4);
      }
      await shot('sealed');
      view.final_state=await healthy();
      if(tag==='390x844') {
        await page.evaluate(()=>window.sevenDistrictCommand('resume'));
        await page.waitForFunction(()=>window.sevenDistrictGame?.menu==='');
        view.street_angles=[];
        for(let angle=0;angle<3;angle++) {
          for(let step=0;step<5;step++) await page.evaluate(()=>window.sevenDistrictCommand('camera_right'));
          await page.waitForTimeout(600);
          const file=`${tag}-street-angle-${angle+1}.png`;
          await page.screenshot({path:path.join(output,file)});
          view.street_angles.push({file,relative_yaw_radians:(angle+1)*1.5,sha256:hash(path.join(output,file)),state:await state()});
        }
      }

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
