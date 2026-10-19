// Actual local Web gameplay. Field saves are produced by content_r2.gd, never fabricated here.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {parseArgs} from 'node:util';
const {values:a}=parseArgs({options:{'playwright-module':{type:'string'},'web-dir':{type:'string'},'data-swap':{type:'boolean',default:false},only:{type:'string'},proof:{type:'boolean',default:false},output:{type:'string',default:'docs/content/r2'}}});
const root=path.resolve(import.meta.dirname,'..'),web=path.resolve(root,a['web-dir']||'.audit-tmp/content-r2/web'),out=path.resolve(root,a.output);
fs.mkdirSync(out,{recursive:true});
const {chromium}=createRequire(import.meta.url)(a['playwright-module']);
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const report={status:'EXECUTED',version:'0.16.0',pck_sha256:sha(path.join(web,'game.pck')),views:[],failures:[],
 method:'Unedited native-size PNGs of actual local Godot Web export, headless Chromium with hardware NVIDIA ANGLE D3D11. Engine.copyToFS imports unmodified native headless-world saves; the target case is always unfinished, while earlier cases may retain native completion. Visible UI performs target collection, retry, sorting, pairing and completion. Long travel resumes from near-source saves, not a continuous walked route. No target-case completion injection, compositing, screenshot scaling or native-device claim.'};
const flags=['--use-angle=d3d11','--enable-gpu','--ignore-gpu-blocklist','--force_high_performance_gpu'];report.gpu_args=flags;
const server=http.createServer((req,res)=>{
 let name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(name.endsWith('/'))name+='index.html';
 const wasm=name==='/game.wasm',file=path.resolve(web,'.'+name+(wasm?'.br':''));
 if(!file.startsWith(web+path.sep)||!fs.existsSync(file)){res.writeHead(404).end();return;}
 res.setHeader('Content-Type',wasm?'application/wasm':({'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png'})[path.extname(file)]||'application/octet-stream');
 if(wasm)res.setHeader('Content-Encoding','br');fs.createReadStream(file).pipe(res);
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin=`http://127.0.0.1:${server.address().port}`;
const assert=(b,s)=>{if(!b)throw Error(s)};let browser;
try{
 browser=await chromium.launch({headless:true,args:flags});report.chromium=browser.version();
 for(const [w,h,dpr,profile] of [[568,320,1,'phone'],[390,844,1,'phone'],[430,932,3,'phone'],[1032,1376,2,'tablet'],[320,568,1,'phone'],[844,390,1,'phone'],[1024,768,1,'tablet'],[1366,600,1,'desktop'],[1366,768,1,'desktop']]){
  const tag=`${w*dpr}x${h*dpr}`;if((a.only&&tag!==a.only)||(a.proof&&tag!=='390x844'))continue;
  const view={tag,viewport:{width:w,height:h},dpr,profile,errors:[],shots:[],checks:[]};report.views.push(view);console.log('VIEW',tag);
  const context=await browser.newContext({viewport:{width:w,height:h},deviceScaleFactor:dpr,hasTouch:true,isMobile:true});
  const page=await context.newPage();page.setDefaultTimeout(90000);
  page.on('pageerror',e=>view.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')view.errors.push(m.text())});
  await context.route('**/*',async route=>{
   const u=new URL(route.request().url());if(['http:','https:'].includes(u.protocol)&&u.origin!==origin){view.errors.push('Remote request '+u.origin);return route.abort();}
   if(u.pathname==='/play-site.js'){
    const response=await route.fetch(),script=await response.text(),marker='engine = new Engine(runtimeConfig);';
    assert(script.includes(marker),'public Engine instance marker');
    return route.fulfill({response,body:script.replace(marker,marker+' window.contentCaptureEngine=engine;')});
   }return route.continue();
  });
  const state=()=>page.evaluate(()=>JSON.parse(JSON.stringify(window.sevenDistrictGame)));
  const healthy=async()=>{
   const s=await state();assert(s.version==='0.16.0','version');assert(!view.errors.length,JSON.stringify(view.errors));
   const ui=s.investigations?.ui;if(ui?.visible){
    for(const b of [...ui.buttons,...ui.labels]){const [x,y,bw,bh]=b.rect;assert(x>=-.5&&y>=-.5&&x+bw<=w+.5&&y+bh<=h+.5,'Offscreen '+b.text);}
    for(const b of ui.buttons){assert(b.rect[2]>=44&&b.rect[3]>=44,'Touch44 '+b.text);}
    for(let i=0;i<ui.buttons.length;i++)for(let j=i+1;j<ui.buttons.length;j++){
     const [x,y,bw,bh]=ui.buttons[i].rect,[a,b,c,d]=ui.buttons[j].rect;assert(!(x<a+c&&a<x+bw&&y<b+d&&b<y+bh),'Button overlap');
    }
   }return s;
  };
  const tap=async b=>{const [x,y,bw,bh]=b.rect;await page.touchscreen.tap(x+bw/2,y+bh/2);await page.waitForTimeout(550);await healthy();};
  const click=async text=>{const s=await healthy(),b=s.investigations.ui.buttons.find(b=>b.text===text&&!b.disabled);assert(b,'Missing enabled button '+text);await tap(b);};
  const shot=async name=>{await page.waitForTimeout(400);const s=await healthy(),file=profile==='phone'&&h>w?`phone-${name}${tag==='390x844'?'':'-'+tag}.png`:`${tag}-${name}.png`;await page.screenshot({path:path.join(out,file)});view.shots.push({file,sha256:sha(path.join(out,file)),state:s});console.log('SHOT',file);};
  const load=async fixture=>{
   const file=path.join(root,'.audit-tmp/content-r2/capture-saves',fixture+'.json'),raw=fs.readFileSync(file),data=JSON.parse(raw);
   assert(data.data.investigations.records[fixture.split('-')[0]].complete===false,'fixture target case must be unfinished');
   view.checks.push({fixture,sha256:sha(file),collected:data.data.investigations.records});
   await page.evaluate(value=>{window.contentCaptureEngine.copyToFS(window.sevenDistrictGame.investigations.save_path,new TextEncoder().encode(JSON.stringify(value)).buffer);window.sevenDistrictCommand('load');},data);
   await page.waitForTimeout(900);await healthy();
  };
  try{
   await page.goto(`${origin}/${profile}/`);await page.locator('#start-button').click();await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title');
   await page.locator('#fullscreen-button').click();await page.waitForTimeout(600);
   await page.evaluate(()=>window.sevenDistrictCommand('new_game'));
   for(let i=0;i<4;i++){await page.keyboard.press('Enter');await page.waitForTimeout(300);}
   await page.waitForFunction(()=>window.sevenDistrictGame?.world_ready&&window.sevenDistrictGame?.play_started);
   view.renderer=await page.evaluate(()=>{const gl=document.querySelector('#canvas').getContext('webgl2'),e=gl.getExtension('WEBGL_debug_renderer_info');return gl.getParameter(e.UNMASKED_RENDERER_WEBGL)});
   assert(/NVIDIA/.test(view.renderer)&&!/SwiftShader/i.test(view.renderer),'hardware renderer');
   await page.evaluate(()=>window.sevenDistrictCommand('pause'));await page.waitForTimeout(500);
   let s=await state();await tap(s.investigations.hud_buttons.find(b=>b.text==='查證'));
   s=await state();await tap(s.investigations.hud_buttons.find(b=>b.text==='街坊查證簿・三宗新案'));
   await shot('case-list');
   if(a['data-swap']){
    await load('second_help-ready');await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);
    await click('第二次求助，第二次收費');
    assert((await state()).investigations.ui.labels.some(l=>l.text.includes('晴橋協助所')&&l.text.includes('橋七')),'compiled replacement document');
    await shot('second_help-data-swap-original');await click('證物已齊，開始推論');
    assert((await state()).investigations.ui.labels.some(l=>l.text.includes('橋七')),'compiled replacement reference');
    await shot('second_help-data-swap');view.status='VERIFIED';continue;
   }
   const full=!a.proof&&['390x844','1290x2796','2064x2752'].includes(tag);
   for(const [id,title,count] of [['second_help','第二次求助，第二次收費',2],['before_night','晚班之前的收據',3],['three_voices','三張嘴，一句真話',3]]){
    if(full){
     await click(title);await shot(id+'-pending');await click('返回街區');
     for(let i=0;i<count;i++){
      await load(id+'-field-'+i);s=await state();assert(s.investigations.field.nearby,'real source proximity '+id+i);
      await shot(id+'-field-'+i);const action=s.investigations.field.actions.find(b=>b.action==='interact');assert(action,'visible interaction');await tap(action);
      s=await state();assert(s.investigations.progress.records[id].collected.length===i+1,'field interaction collects one source');
      await shot(id+'-original-'+i);await click('返回街區');
     }
    }
    await load(id+'-ready');await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);await click(title);
    await click(h<400?'推論':'證物已齊，開始推論');
    if(id==='second_help'){
     await shot(id+'-compare');await click('補充通知較晚，已取代原承諾');assert(!(await state()).investigations.progress.records[id].complete,'bad comparison cannot finish');
     await shot(id+'-retry');await click('不收預付費／先付代辦費');
     s=await state();assert(s.investigations.progress.records[id].compared&&!s.investigations.progress.records[id].complete,'first layer does not seal');await shot(id+'-action');
     await click('先刪掉舊承諾，只保留最新通知');assert(!(await state()).investigations.progress.records[id].complete,'bad action cannot finish');await shot(id+'-action-retry');
     await click('返回街區');await page.waitForTimeout(1800);
     if(tag==='390x844'){
      await page.reload();await page.locator('#start-button').click();await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title'&&window.sevenDistrictGame?.world_ready);
      await page.locator('#fullscreen-button').click();await page.waitForTimeout(600);
     }
     await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(900);
     s=await state();assert(s.investigations.progress.records[id].compared&&!s.investigations.progress.records[id].complete,'IndexedDB first-layer cold reload');
     view.checks.push({first_layer_saved:true,reload:tag==='390x844'?'IndexedDB cold reload':'normal disk load',still_unsealed:true});
     await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);await click(title);await click('推論');await shot(id+'-action-reloaded');await click('停止付款，保存兩份文件並尋求協助');
    }else if(id==='before_night'){
     if(tag==='390x844'&&!a.proof){
      const orders=[];
      for(let attempt=0;attempt<10;attempt++){
       await click('案件清單');await click(title);await click('推論');
       const cards=(await state()).investigations.ui.buttons.filter(b=>/^[甲乙丙] /.test(b.text));
       orders.push(cards.map(b=>b.text));assert(orders.at(-1).join('|')==='丙 18：00|甲 17：42|乙 17：55','ten visible UI reopens stay unsorted');
      }
      view.checks.push({timeline_ten_ui_opens:orders,chronological_opens:0,status:'VERIFIED'});
     }
     s=await state();const cards=s.investigations.ui.buttons.filter(b=>/^[甲乙丙] /.test(b.text));assert(cards.map(b=>b.text).join('|')==='丙 18：00|甲 17：42|乙 17：55','unsorted visual cards');
     await shot(id+'-unsorted');for(const t of ['丙 18：00','甲 17：42','乙 17：55','確認時間線'])await click(t);
     assert(!(await state()).investigations.progress.records[id].complete,'bad timeline cannot finish');await shot(id+'-wrong');
     for(let i=0;i<3;i++)await click('撤回最後一張');await shot(id+'-undo');
     for(const t of ['甲 17：42','乙 17：55','丙 18：00'])await click(t);await shot(id+'-arranged');await click('確認時間線');
    }else{
     await click('甲 首筆17：50');await click('支持這句');assert(Object.keys((await state()).investigations.progress.records[id].pairs).length===0,'wrong pairing');await shot(id+'-retry');
     for(let i=0;i<3;i++){
      // Complete index is a valid counterexample to either universal statement.
      await click('丙 三筆索引');await shot(id+'-statement-'+i);await click(i===2?'支持這句':'推翻這句');
      if(i<2){
       assert((await state()).investigations.progress.records[id].pairs[String(i)][0]===2,'complete index accepted as counterexample');
       await shot(id+'-index-accepted-'+i);
       await click(i===0?'乙 末筆18：10':'甲 首筆17：50');await click('推翻這句');
       assert((await state()).investigations.progress.records[id].pairs[String(i)][0]===(i===0?1:0),'valid pair can be replaced without penalty');
       await click(`換一句 ${i+1}／3`);
      }
     }
    }
    await shot(id+'-sealed');s=await state();assert(s.investigations.progress.records[id].complete,'completed '+id);
    assert(s.investigations.ui.art.includes('/content-r2/'+id+'.webp')||w<360||h<700,'case-specific art');
    await click('返回街區');await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(800);assert((await state()).investigations.progress.records[id].complete,'disk load completion');
    await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);
    view.checks.push({case:id,status:'VERIFIED',completed:true,saved:true,wrong_retry:true});
   }
   await page.waitForTimeout(1800);await page.reload();await page.locator('#start-button').click();await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title'&&window.sevenDistrictGame?.world_ready);
   await page.locator('#fullscreen-button').click();await page.waitForTimeout(600);
   await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(900);assert(Object.values((await state()).investigations.progress.records).every(r=>r.complete),'all completions survive IndexedDB cold reload');
   await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);await shot('case-list-reloaded');
   for(const [id,title] of [['second_help','第二次求助，第二次收費'],['before_night','晚班之前的收據'],['three_voices','三張嘴，一句真話']]){
    await click('已封存｜'+title);await shot(id+'-sealed-reloaded');await click('案件清單');
   }
   view.checks.push({indexeddb_cold_reload:'VERIFIED',all_cases_complete:true});view.status='VERIFIED';
  }catch(e){view.status='BLOCKED';view.failure=e.stack;view.failure_state=await state().catch(()=>null);report.failures.push({tag,message:e.message});console.log('FAIL',tag,e.message);}
  finally{await context.close();fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(report,null,2)+'\n');}
  if(report.failures.length)break;
 }
 report.status=report.failures.length?'BLOCKED':'VERIFIED';
}finally{if(browser)await browser.close();await new Promise(r=>server.close(r));fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify({status:report.status,views:report.views.length,failures:report.failures}));if(report.failures.length)process.exitCode=1;
