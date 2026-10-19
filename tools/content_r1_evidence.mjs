// Local Web captures. Fixtures are real native field saves; solving uses visible UI.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import os from 'node:os';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
import {parseArgs} from 'node:util';
const {values:a}=parseArgs({options:{'playwright-module':{type:'string'},only:{type:'string'},'skip-perf':{type:'boolean',default:false},output:{type:'string',default:'docs/content/r1/screenshots'}}});
const root=path.resolve(import.meta.dirname,'..'),web=path.join(root,'.audit-tmp/content-r1/web'),out=path.resolve(root,a.output);
fs.mkdirSync(out,{recursive:true});
const {chromium}=createRequire(import.meta.url)(a['playwright-module']);
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
// Snapshot valid native fixtures once, avoiding races with a parallel final suite.
const nativeFixtures=Object.fromEntries(['second_help','before_night','three_voices'].map(id=>{
 const file=path.join(root,'.audit-tmp/content-r1/capture-saves',id+'.json'),raw=fs.readFileSync(file);
 return [id,{envelope:JSON.parse(raw),sha256:crypto.createHash('sha256').update(raw).digest('hex')}];
}));
const gpuArgs=['--use-angle=d3d11','--enable-gpu','--ignore-gpu-blocklist','--force_high_performance_gpu'];
const report={status:'EXECUTED',version:'0.15.0',pck_sha256:sha(path.join(web,'game.pck')),gpu_args:gpuArgs,
  method:'Unedited native-size headless Chromium Web screenshots. The documented Godot Engine.copyToFS API imports actual headless-world field saves into an isolated browser. Normal Load validates them. No completion is injected: every wrong attempt, reorder, evidence pairing and conclusion uses actual visible buttons. Native tests independently cover field proximity and collection. Browser images are not native iOS captures.',
  environment:'並發載量測，僅供參考',views:[],host_load:[],gpu_load:[],failures:[]};
let lastCpu=os.cpus();
const monitor=setInterval(()=>{const now=os.cpus();let idle=0,total=0;for(let i=0;i<now.length;i++)for(const [key,value] of Object.entries(now[i].times)){const delta=value-lastCpu[i].times[key];total+=delta;if(key==='idle')idle+=delta;}lastCpu=now;report.host_load.push({at:new Date().toISOString(),cpu_percent:100*(1-idle/Math.max(1,total)),free_memory_bytes:os.freemem()});},1000);
const gpu=spawn('nvidia-smi',['--query-gpu=utilization.gpu,memory.used,memory.total','--format=csv,noheader,nounits','-l','1'],{windowsHide:true});
gpu.stdout.on('data',b=>report.gpu_load.push({at:new Date().toISOString(),value:b.toString().trim()}));
gpu.on('error',e=>report.gpu_monitor_error=e.message);
const server=http.createServer((req,res)=>{
  let name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(name.endsWith('/'))name+='index.html';
  const wasm=name==='/game.wasm',file=path.resolve(web,'.'+name+(wasm?'.br':''));
  if(!file.startsWith(web+path.sep)||!fs.existsSync(file)){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',wasm?'application/wasm':({'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png'})[path.extname(file)]||'application/octet-stream');
  if(wasm)res.setHeader('Content-Encoding','br');fs.createReadStream(file).pipe(res);
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const origin=`http://127.0.0.1:${server.address().port}`;
const assert=(b,s)=>{if(!b)throw Error(s)};
let browser;
try{
 browser=await chromium.launch({headless:true,args:gpuArgs});report.chromium=browser.version();
 const matrix=[[390,844,1,'phone'],[844,390,1,'phone'],[320,568,1,'phone'],[568,320,1,'phone'],[430,932,3,'phone'],[1032,1376,2,'tablet'],[1024,768,1,'tablet'],[1366,600,1,'desktop'],[1366,768,1,'desktop']];
 for(const [width,height,dpr,profile] of matrix){
  const tag=`${width*dpr}x${height*dpr}`;if(a.only&&tag!==a.only)continue;
  const view={tag,viewport:{width,height},dpr,profile,errors:[],shots:[],checks:[]};report.views.push(view);console.log('VIEW',tag);
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:dpr,hasTouch:true,isMobile:true});
  const page=await context.newPage();page.setDefaultTimeout(90000);
  page.on('pageerror',e=>view.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')view.errors.push(m.text())});
  await context.route('**/*',async route=>{
   const u=new URL(route.request().url());if(['http:','https:'].includes(u.protocol)&&u.origin!==origin){view.errors.push('Remote request '+u.origin);return route.abort();}
   if(u.pathname==='/play-site.js'){
    const response=await route.fetch();const script=await response.text();
    const marker='engine = new Engine(runtimeConfig);';
    assert(script.includes(marker),'Expected local web adapter instance');
    return route.fulfill({response,body:script.replace(marker,marker+' window.contentCaptureEngine=engine;')});
   }
   return route.continue();
  });
  const state=()=>page.evaluate(()=>JSON.parse(JSON.stringify(window.sevenDistrictGame)));
  const visible=async()=>{const s=await state();assert(s.version==='0.15.0','version');assert(!view.errors.length,JSON.stringify(view.errors));if(s.investigations?.ui.visible){const buttons=s.investigations.ui.buttons;for(const b of buttons){const [x,y,w,h]=b.rect;assert(x>=-.5&&y>=-.5&&x+w<=width+.5&&y+h<=height+.5,'Offscreen '+b.text);assert(w>=44&&h>=44,'Small touch target '+b.text);}for(let i=0;i<buttons.length;i++)for(let j=i+1;j<buttons.length;j++){const [x,y,w,h]=buttons[i].rect,[a,b,c,d]=buttons[j].rect;assert(!(x<a+c&&a<x+w&&y<b+d&&b<y+h),'Overlapping buttons');}}return s;};
  const click=async text=>{const s=await visible();const b=s.investigations.ui.buttons.find(b=>b.text===text&&!b.disabled);assert(b,'Missing enabled button '+text);const [x,y,w,h]=b.rect;await page.mouse.click(x+w/2,y+h/2);await page.waitForTimeout(400);await visible();};
  const shot=async name=>{await page.waitForTimeout(500);const s=await visible();const file=`${tag}-${name}.png`;await page.screenshot({path:path.join(out,file)});view.shots.push({file,sha256:sha(path.join(out,file)),state:s});console.log('SHOT',file);};
  try{
   await page.goto(`${origin}/${profile}/`);await page.locator('#start-button').click();
   await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title');
   await page.locator('#fullscreen-button').click();await page.waitForTimeout(600);
   await page.evaluate(()=>window.sevenDistrictCommand('new_game'));
   for(let i=0;i<4;i++){await page.keyboard.press('Enter');await page.waitForTimeout(300);}
   await page.waitForFunction(()=>window.sevenDistrictGame?.world_ready&&window.sevenDistrictGame?.play_started);
   await page.waitForTimeout(1200);
   view.renderer=await page.evaluate(()=>{const g=document.querySelector('#canvas').getContext('webgl2'),e=g.getExtension('WEBGL_debug_renderer_info');return g.getParameter(e.UNMASKED_RENDERER_WEBGL)});
   assert(/NVIDIA/.test(view.renderer)&&!/SwiftShader/i.test(view.renderer),'Hardware renderer required');
   if(!a['skip-perf']&&['390x844','1366x768'].includes(tag)){
    view.frame_pacing={runs:[]};
    for(let run=0;run<3;run++)view.frame_pacing.runs.push(await page.evaluate(()=>new Promise(resolve=>{const values=[];let prev=0;function tick(t){if(prev)values.push(t-prev);prev=t;if(values.length<180)requestAnimationFrame(tick);else{const sorted=[...values].sort((a,b)=>a-b);resolve({frames:180,p95_ms:sorted[170],p50_ms:sorted[89],raw_ms:values,game_process_ms:window.sevenDistrictGame.process_ms});}}requestAnimationFrame(tick)})));
    view.frame_pacing.p95_median_ms=view.frame_pacing.runs.map(x=>x.p95_ms).sort((a,b)=>a-b)[1];
    view.frame_pacing.threshold_ms=18;view.frame_pacing.status=view.frame_pacing.p95_median_ms<=18?'VERIFIED':'BLOCKED';
   }
   await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await shot('case-list');
   for(const [id,title] of [['second_help','第二次求助，第二次收費'],['before_night','晚班之前的收據'],['three_voices','三張嘴，一句真話']]){
    // The test-produced native envelope is unmodified and hash-recorded.
    const {envelope,sha256}=nativeFixtures[id];
    view.checks.push({fixture:id,sha256,collected:envelope.data.investigations.records[id].collected});
    await page.evaluate(value=>{const p=window.sevenDistrictGame.investigations.save_path;window.contentCaptureEngine.copyToFS(p,new TextEncoder().encode(JSON.stringify(value)).buffer);window.sevenDistrictCommand('load');},envelope);
    await page.waitForFunction(id=>window.sevenDistrictGame?.investigations?.progress?.active===id,id);
    await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);
    await click((envelope.data.investigations.records[id].complete?'已封存｜':'')+title);
    await shot(id+'-evidence');await click(height<400?'推論':'證物已齊，開始推論');
    if(id==='second_help'){
     await click('兩份文件的紙色不同');assert(!(await state()).investigations.progress.records[id].complete,'wrong choice finished');
     await shot(id+'-retry');await click('不收預付費／先付代辦費');
    }else if(id==='before_night'){
     for(const t of ['丙 18：00','甲 17：42','乙 17：55','確認時間線'])await click(t);
     assert(!(await state()).investigations.progress.records[id].complete,'wrong order finished');
     for(let i=0;i<3;i++)await click('撤回最後一張');
     for(const t of ['甲 17：42','乙 17：55','丙 18：00'])await click(t);
     await shot('timeline-arranged');await click('確認時間線');
    }else{
     await click('甲 首筆17：50');await click('支持這句');
     assert(Object.keys((await state()).investigations.progress.records[id].pairs).length===0,'wrong pair accepted');
     for(let i=0;i<3;i++){
      await click(['乙 末筆18：10','甲 首筆17：50','丙 三筆索引'][i]);
      if(i===1)await shot('testimony-crosscheck');
      await click(i===2?'支持這句':'推翻這句');if(i<2)await click(`換一句 ${i+1}／3`);
     }
    }
    await shot(id+'-sealed');assert((await state()).investigations.progress.records[id].complete,'case not complete '+id);
    await click('返回街區');await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(700);
    assert((await state()).investigations.progress.records[id].complete,'disk save did not preserve '+id);
    view.checks.push({case:id,status:'VERIFIED',wrong_retry:true,completed:true,loaded_from_disk:true});
   }
   await page.waitForTimeout(2500);await page.reload();await page.locator('#start-button').click();
   await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title');
   await page.waitForFunction(()=>window.sevenDistrictGame?.world_ready);
   await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(900);
   assert(Object.values((await state()).investigations.progress.records).every(r=>r.complete),'IndexedDB cold reload lost a completion');
   view.checks.push({indexeddb_cold_reload:'VERIFIED',all_cases_complete:true});
   view.status='VERIFIED';
  }catch(e){view.status='BLOCKED';view.failure=e.stack;report.failures.push({tag,message:e.message});console.log('FAIL',tag,e.message);}
  finally{await context.close();fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(report,null,2)+'\n');}
 }
 report.status=report.failures.length?'BLOCKED':'VERIFIED';
}finally{
 clearInterval(monitor);gpu.kill();if(browser)await browser.close();await new Promise(r=>server.close(r));
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify({status:report.status,views:report.views.length,failures:report.failures}));
if(report.failures.length)process.exitCode=1;
