// Actual local Web gameplay. R4 native-world fixtures remain unfinished; visible touch input completes the R10 cases.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {parseArgs} from 'node:util';
const {values:a}=parseArgs({options:{'playwright-module':{type:'string'},'chromium-executable':{type:'string'},'fixture-dir':{type:'string'},'web-dir':{type:'string'},'data-swap':{type:'boolean',default:false},only:{type:'string'},proof:{type:'boolean',default:false},output:{type:'string',default:'docs/content/r10'}}});
const root=path.resolve(import.meta.dirname,'..'),web=path.resolve(root,a['web-dir']||'.audit-tmp/content-r10/web'),out=path.resolve(root,a.output);
fs.mkdirSync(out,{recursive:true});
const {chromium}=createRequire(import.meta.url)(a['playwright-module']);
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const report={status:'EXECUTED',version:'0.24.0',pck_sha256:sha(path.join(web,'game.pck')),views:[],failures:[],
 method:'Unedited native-size PNGs of actual local Godot Web export, headless Chromium with hardware NVIDIA ANGLE D3D11. Engine.copyToFS resumes the unfinished target from native headless-world near-source saves, preserving earlier cases actually completed in this browser. The target completion is never injected. Visible UI performs target collection, retry, sorting, pairing and completion. Long travel resumes from near-source saves, not a continuous walked route. No target-case completion injection, compositing, screenshot scaling or native-device claim.'};
const flags=['--use-angle=d3d11','--enable-gpu','--ignore-gpu-blocklist','--force_high_performance_gpu'];report.gpu_args=flags;
report.guards=['touch44','button_bounds','button_overlap','label_bounds','label_overlap','cjk_line_start','drag_preview_matches_drop','drag_cancel_preserves_order','no_remote_requests'];
report.touch_press_ms=350;
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
 browser=await chromium.launch({headless:true,args:flags,executablePath:a['chromium-executable']});report.chromium=browser.version();
 for(const [w,h,dpr,profile] of [[390,844,1,'phone'],[320,568,1,'phone'],[430,932,3,'phone'],[1032,1376,2,'tablet'],[844,390,1,'phone'],[1024,768,1,'tablet']]){
  const tag=`${w*dpr}x${h*dpr}`;if(!['320x568','390x844','1290x2796','2064x2752','844x390','1024x768'].includes(tag))continue;if((a.only&&!a.only.split(',').includes(tag))||(a.proof&&tag!=='390x844'))continue;
  const view={tag,viewport:{width:w,height:h},dpr,profile,errors:[],shots:[],checks:[]};report.views.push(view);console.log('VIEW',tag);
  const context=await browser.newContext({viewport:{width:w,height:h},deviceScaleFactor:dpr,hasTouch:true,isMobile:true});
  const page=await context.newPage();page.setDefaultTimeout(90000);
  const input=await context.newCDPSession(page);
  page.on('pageerror',e=>view.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')view.errors.push(m.text())});
  await context.route('**/*',async route=>{
   const u=new URL(route.request().url());if(['http:','https:'].includes(u.protocol)&&u.origin!==origin){view.errors.push('Remote request '+u.origin);return route.abort();}
   if(u.pathname==='/play-site.js'){
    const response=await route.fetch(),script=await response.text(),marker='engine = new Engine(runtimeConfig);';
    assert(script.includes(marker),'public Engine instance marker');
    return route.fulfill({response,body:script.replace(marker,marker+' window.contentCaptureEngine=engine;')});
   }return route.continue();
  });
  const archived={};
  process.once('SIGINT',()=>{browser?.close().finally(()=>process.exit(130));});
  const state=()=>page.evaluate(()=>JSON.parse(JSON.stringify(window.sevenDistrictGame)));
  const pace=async()=>{
   const runs=[];
   for(let run=0;run<3;run++)runs.push(await page.evaluate(()=>new Promise(resolve=>{
    let prev;const values=[];
    function tick(t){if(prev!==undefined)values.push(t-prev);prev=t;if(values.length<180)requestAnimationFrame(tick);else {values.sort((a,b)=>a-b);resolve({frames:180,p50:values[89],p95:values[170],max:values.at(-1)});}}
    requestAnimationFrame(tick);
   })));
   return {method:'3 x 180 browser RAF presentation intervals; concurrent host load; reference only, not native GPU timings',runs,p95_median:runs.map(r=>r.p95).sort((a,b)=>a-b)[1]};
  };
  const healthy=async()=>{
   const s=await state();assert(s.version==='0.24.0','version');assert(!view.errors.length,JSON.stringify(view.errors));
   const ui=s.investigations?.ui;if(ui?.visible){
    for(const b of [...ui.buttons,...ui.labels]){const [x,y,bw,bh]=b.rect;assert(x>=-.5&&y>=-.5&&x+bw<=w+.5&&y+bh<=h+.5,'Offscreen '+b.text);}
    for(const b of ui.buttons){assert(b.rect[2]>=44&&b.rect[3]>=44,'Touch44 '+b.text);}
    for(const label of [...ui.labels,...ui.buttons]){
     for(const term of ['車店收據','輪值資料','交接摘要','工作天','原件影本','前後合看','甲先發','乙後補']){assert((label.rendered_text||label.text).split(term).length===label.text.split(term).length,'Split Chinese phrase '+term+' in '+label.text);}
     for(const line of (label.rendered_text||label.text).split('\n')){assert(!/^[。，：；？！」』）、]/.test(line),'Orphan punctuation '+label.text);assert(!/^[\p{Script=Han}][。，：；？！、」』）]?$/u.test(line),'Orphan CJK glyph '+label.text);}
    }
    for(let i=0;i<ui.buttons.length;i++)for(let j=i+1;j<ui.buttons.length;j++){
     const [x,y,bw,bh]=ui.buttons[i].rect,[a,b,c,d]=ui.buttons[j].rect;assert(!(x<a+c&&a<x+bw&&y<b+d&&b<y+bh),'Button overlap');
    }
    for(let i=0;i<ui.labels.length;i++)for(let j=i+1;j<ui.labels.length;j++){
     const [x,y,bw,bh]=ui.labels[i].rect,[a,b,c,d]=ui.labels[j].rect;
     assert(!(x<a+c&&a<x+bw&&y<b+d&&b<y+bh),'Label overlap '+ui.labels[i].text+' / '+ui.labels[j].text);
    }
   }return s;
  };
  const tap=async b=>{
   assert(b,'Visible touch target');const [x,y,bw,bh]=b.rect;
   await input.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:x+bw/2,y:y+bh/2,id:0}]});
   await page.waitForTimeout(350);
   await input.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   await page.waitForTimeout(650);await healthy();
  };
  const click=async text=>{
   await page.waitForFunction(text=>window.sevenDistrictGame?.investigations?.ui?.buttons?.some(b=>b.text===text&&!b.disabled),text,{timeout:5000});
   const s=await healthy(),b=s.investigations.ui.buttons.find(b=>b.text===text&&!b.disabled);assert(b,'Missing enabled button '+text);await tap(b);
   const after=await healthy();
   if(JSON.stringify(after.investigations.ui)===JSON.stringify(s.investigations.ui)&&JSON.stringify(after.investigations.progress)===JSON.stringify(s.investigations.progress)){
    const same=after.investigations.ui.buttons.find(x=>x.text===text&&!x.disabled&&JSON.stringify(x.rect)===JSON.stringify(b.rect));
    if(same){view.checks.push({guarded_unchanged_touch_repeat:text});await tap(same);}
   }
  };
  const shot=async (name,delay=120)=>{
   await page.waitForTimeout(delay);const s=await healthy();
   const supplemental=tag==='320x568'?/paper-[ab]-(unmarked|marked)|wrong-field|drag-preview-[123]|relation-retry|relations-chosen|middle-to-left|shuffled|attachment-picked|statement-2|pinning-last|sealed(?:-reloaded)?$/:['1290x2796','2064x2752','844x390','1024x768'].includes(tag)?/paper-b-marked|attachment-picked|relations-chosen|support-both-sides|action-options|judgment-chosen|sealed$/:/sealed$/;
   if(tag!=='390x844'&&!supplemental.test(name))return;
   const file=profile==='phone'&&h>w?`phone-${name}${tag==='390x844'?'':'-'+tag}.png`:`${tag}-${name}.png`;
   await page.screenshot({path:path.join(out,file)});view.shots.push({file,sha256:sha(path.join(out,file)),state:s});console.log('SHOT',file);
  };
  const load=async (fixture,preserveTarget=false)=>{
   const file=path.resolve(root,a['fixture-dir']||'.audit-tmp/content-r10/release-saves',fixture+'.json'),raw=fs.readFileSync(file),data=JSON.parse(raw);
   assert(data.data.investigations.records[fixture.split('-')[0]].complete===false,'fixture target case must be unfinished');
   const prior=await state(),target=fixture.split('-')[0];
   for(const [id,record] of Object.entries(prior.investigations.progress.records)){
    if((id!==target&&archived[id])||(id===target&&preserveTarget)){if(id!==target)assert(record.complete,'earlier case still complete');data.data.investigations.records[id]=record;}
   }
   view.checks.push({fixture,sha256:sha(file),collected:data.data.investigations.records,retained_actual_earlier_cases:Object.keys(archived)});
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


   const returnToCase=async(id,title)=>{
    await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);
    await click((await state()).investigations.ui.buttons.find(b=>b.text.endsWith('｜'+title)).text);
   };
   const street=async(id,title,choice=null)=>{
    await load(id+'-field-'+(id==='three_voices'?2:0),true);
    if(choice!==null){await returnToCase(id,title);await click(['實際處置','付款回放','單件回放'][choice]);}
    await page.waitForTimeout(1000);
    const result=(await state()).investigations.street_result;
    assert(result.count===(id==='second_help'?(choice===2?1:2):id==='before_night'?3:2),'street object count');
    assert((await state()).investigations.street_objects.objects===result.count,'real visible retained-paper meshes');
    await shot(id+'-street-'+(choice===null?'result':['actual','payment-replay','latest-replay'][choice]));
   };
   const full=!a.proof&&tag==='390x844';
   for(const [id,title,count] of [['second_help','第二次求助，第二次收費',2],['before_night','晚班之前的收據',3],['three_voices','三張嘴，一句真話',3]]){
    if(full){
     await click((await state()).investigations.ui.buttons.find(b=>b.text.endsWith('｜'+title)).text);await shot(id+'-pending');await click('返回街區');
     for(let i=0;i<count;i++){
      await load(id+'-field-'+i);s=await state();assert(s.investigations.field.nearby,'real source proximity '+id+i);
      await shot(id+'-field-'+i);
      if(id==='second_help'&&i===0&&['390x844','1290x2796','2064x2752','844x390','1024x768'].includes(tag)){
       view.performance=await pace();
      }
      let attempts=0;
      while(attempts<3){
       s=await state();if(s.investigations.progress.records[id].collected.length===i+1)break;
       assert(s.phase==='playing'&&s.investigations.field.nearby&&s.investigations.progress.records[id].collected.length===i,'guarded input retry only while same source is still uncollected');
       const action=s.investigations.field.actions.find(b=>b.action==='interact');assert(action,'visible interaction');await tap(action);attempts++;
       await page.waitForFunction(({id,count})=>window.sevenDistrictGame.investigations.progress.records[id].collected.length===count,{id,count:i+1},{timeout:3000}).catch(()=>{});
      }
      view.checks.push({field_touch:{case:id,source:i,attempts}});
      s=await state();assert(s.investigations.progress.records[id].collected.length===i+1,'field interaction collects exactly one source');
      await shot(id+'-original-'+i);await click('返回街區');
     }
    }
    await load(id+'-ready');await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);await click((await state()).investigations.ui.buttons.find(b=>b.text.endsWith('｜'+title)).text);
    await click(h<400?'推論':'證物已齊，開始推論');
    if(id==='second_help'){
     await shot(id+'-paper-a-unmarked');
     await click('案號：岸七');await shot(id+'-wrong-field');
     await click('期限：收件後三個工作天回覆。');await shot(id+'-wrong-sentence');
     assert(!(await state()).investigations.progress.records[id].citations['0'],'wrong sentence never highlights');
     assert((await state()).investigations.ui.buttons.find(b=>b.text==='核對兩處黃標').disabled,'two fee highlights required');
     assert((await state()).investigations.progress.records[id].viewed_fields['0'].includes(1),'wrong paper field retained');
     await click('承諾：本案協助不收任何預付費。');await shot(id+'-paper-a-marked');
     const evidenceEntry=async()=>{await click('案件清單');await click((await state()).investigations.ui.buttons.find(b=>b.text.endsWith('｜'+title)).text);};
     if(h<400)await evidenceEntry();
     await click('放大');await shot(id+'-paper-a-magnified');
     if(h<400)await evidenceEntry();
     await click('推論');
     await click('返回街區');await page.waitForTimeout(1800);
     if(tag==='390x844'){
      await page.reload();await page.locator('#start-button').click();await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title'&&window.sevenDistrictGame?.world_ready);
      await page.locator('#fullscreen-button').click();await page.waitForTimeout(600);
     }
     await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(900);
     s=await state();assert(s.investigations.progress.records[id].citations['0']===2&&!s.investigations.progress.records[id].complete,'paper mark survives cold reload');
     view.checks.push({paper_mark_saved:true,reload:tag==='390x844'?'IndexedDB cold reload':'normal disk load',still_unsealed:true});
     await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);await click((await state()).investigations.ui.buttons.find(b=>b.text.endsWith('｜'+title)).text);await click('推論');await shot(id+'-paper-a-reloaded');
     await click('乙 原件');await shot(id+'-paper-b-unmarked');await click('期限：本通知保留七日供核對。');await shot(id+'-paper-b-wrong-sentence');await click('要求：本案須先付代辦費，才受理協助。');await shot(id+'-paper-b-marked');
     await click('核對兩處黃標');await shot(id+'-spread-before-seal');
     assert((await state()).investigations.progress.records[id].compared&&!(await state()).investigations.progress.records[id].complete,'paper comparison does not seal');
     await shot(id+'-action-options');
     await click('照乙付款，留存甲乙兩份原件');await shot(id+'-action-payment-retry');
     if(tag==='390x844'){await load(id+'-field-0',true);await shot(id+'-street-payment-provisional');await returnToCase(id,title);await click('推論');}
     assert(!(await state()).investigations.progress.records[id].complete,'payment choice cannot seal');
     await click('暫停付款，留存最新乙件原件');await shot(id+'-action-latest-only-retry');
     if(tag==='390x844'){await load(id+'-field-0',true);await shot(id+'-street-latest-provisional');await returnToCase(id,title);await click('推論');}
     assert(!(await state()).investigations.progress.records[id].complete,'latest-only retention cannot seal');
     await click('暫停付款，留存甲乙兩份原件');
     view.checks.push({evidence_body_comparison:'VERIFIED',document_a_field:'承諾',document_b_field:'要求',paper_citations_saved:true});
    }else if(id==='before_night'){
     const masked=async label=>{const ui=(await state()).investigations.ui;assert(!/(17[：:]42|17[：:]55|18[：:]00)/.test(JSON.stringify([...ui.buttons,...ui.labels])),label+' no visible time');};
     await masked('unsorted');await shot(id+'-unsorted');await shot(id+'-placed-0');await click('打亂牌位');await masked('shuffled');await shot(id+'-shuffled');
     const drag=async(index,slot,frames=false)=>{
      const ui=(await healthy()).investigations.ui,letter=['甲','乙','丙'][index],card=ui.buttons.find(b=>b.text.startsWith(letter+' ')),r=ui.drop_zone;
      assert(card&&r.length===4,'real drag targets');const [x,y,bw,bh]=card.rect,sx=x+bw/2,sy=y+bh/2,dx=r[0]+r[2]*(slot+.5)/3,dy=r[1]+r[3]*.75;
      await input.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:sx,y:sy,id:4}]});
      await page.waitForTimeout(100);
      if(frames){
       for(let preview=0;preview<3;preview++){
        const px=r[0]+r[2]*(preview+.5)/3;
        await input.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:px,y:dy,id:4}]});
        await page.waitForTimeout(600);await masked('drag_preview');await shot(id+'-drag-preview-'+(preview+1),0);
        assert((await state()).investigations.ui.preview_slot===preview,'visible exact slot preview');
        const current=(await state()).investigations.progress.records[id].order.filter(i=>i!==index);current.splice(Math.min(preview,current.length),0,index);
        assert((await state()).investigations.ui.labels.some(l=>l.text==='放下後：'+current.map(i=>['甲','乙','丙'][i]).join(' → ')),'preview describes exact insertion result');assert(JSON.stringify((await state()).investigations.ui.slot_order)===JSON.stringify(current),'actual visible slots match preview');assert((await state()).investigations.ui.ghost_text.includes('時間被遮蔽'),'full ghost includes masked time');
        const ghost=(await state()).investigations.ui.ghost_rect;const paper=(await state()).investigations.ui.paper_rect;assert(ghost.length===4&&ghost[0]>=paper[0]+8&&ghost[0]+ghost[2]<=paper[0]+paper[2]-8,'ghost stays inside paper with safe margins');
       }
      }
      for(let k=1;k<=5;k++){
       await input.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:sx+(dx-sx)*k/5,y:sy+(dy-sy)*k/5,id:4}]});await page.waitForTimeout(60);
      }
      await input.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page.waitForTimeout(450);await healthy();
     };
     await drag(2,0);assert((await state()).investigations.progress.records[id].order.join(',')==='2','real touch drop');await masked('sorting');await shot(id+'-sorting');await shot(id+'-placed-1');
     await drag(0,1);await shot(id+'-placed-2');await drag(1,2);await shot(id+'-placed-3');assert((await state()).investigations.progress.records[id].order.join(',')==='2,0,1','initial mixed order');
     for(let target=0;target<3;target++){await drag(0,target,target===0);assert((await state()).investigations.progress.records[id].order.join(',')===[[0,2,1],[2,0,1],[2,1,0]][target].join(','),'three actual drops match three preview orders');await shot(id+'-actual-drop-'+(target+1));}await drag(0,0);assert((await state()).investigations.progress.records[id].order.join(',')==='0,2,1','middle card moves to left immediately');await shot(id+'-middle-to-left');
     {
      const before=await state(),ui=before.investigations.ui,card=ui.buttons.find(b=>b.text.startsWith('甲 '));const [x,y,cw,ch]=card.rect;
      await input.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:x+cw/2,y:y+ch/2,id:5}]});
      await input.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:w/2,y:ui.drop_zone[1]+ui.drop_zone[3]/2,id:5}]});
      await page.waitForTimeout(150);
      await input.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:w/2,y:ui.drop_zone[1]-10,id:5}]});
      await input.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page.waitForTimeout(450);
      const after=await healthy();assert(JSON.stringify(before.investigations.progress.records[id].order)===JSON.stringify(after.investigations.progress.records[id].order)&&!after.investigations.ui.dragging,'cancel outside slots preserves exact order');
      await shot(id+'-drag-cancelled');
     }
     await drag(1,1);assert((await state()).investigations.progress.records[id].order.join(',')==='0,1,2','real touch reorder');await masked('arranged');await shot(id+'-arranged');
     await click('撤回末張');assert((await state()).investigations.progress.records[id].order.join(',')==='0,1','undo real UI');await shot(id+'-undo');
     s=await state();await click(s.investigations.ui.buttons.find(b=>b.text.startsWith('丙 ')).text);assert((await state()).investigations.progress.records[id].order.join(',')==='0,1,2','tap alternative');await shot(id+'-tap-alternative');
     await click('核對關係');await shot(id+'-relations-empty');assert((await state()).investigations.ui.buttons.find(b=>b.text==='揭時核對').disabled,'missing both disables reveal');await click('交接摘要 → 車店收據');await shot(id+'-relations-one');assert((await state()).investigations.ui.buttons.find(b=>b.text==='揭時核對').disabled,'missing second disables reveal');await click('乙與丙');await click('交接摘要 → 輪值資料');assert((await state()).investigations.ui.buttons.find(b=>b.text==='揭時核對').disabled,'wrong direction disables reveal');
     assert(!(await state()).investigations.progress.records[id].time_checked,'wrong original relation cannot advance');await click('甲與乙');await shot(id+'-relation-retry');
     await click('甲與乙');await shot(id+'-relations-a-options');await click('車店收據 → 交接摘要');await click('乙與丙');await click('輪值資料 → 交接摘要');await shot(id+'-relation-b-retry');assert((await state()).investigations.ui.buttons.find(b=>b.text==='揭時核對').disabled,'second wrong link disables reveal');await click('交接摘要 → 輪值資料');await shot(id+'-relations-chosen');
     await click('揭時核對');await shot(id+'-revealing-1',0);await page.waitForTimeout(800);await shot(id+'-revealing-2',0);await page.waitForTimeout(1400);assert(!(await state()).investigations.progress.records[id].complete,'reveal alone cannot seal');await shot(id+'-revealed');
     await click('17：42\n點選拿起收據');await shot(id+'-attachment-picked');await click('18：00\n貼入收據 →');
    }else{
     await click('首筆 林秀蘭\n17：50');await click('支持這句');assert(Object.keys((await state()).investigations.progress.records[id].pairs).length===0,'wrong pairing');await shot(id+'-retry');
     for(let i=0;i<3;i++){
      // Complete index is a valid counterexample to either universal statement.
      await click('索引 吳安琪');await shot(id+'-statement-'+i);await click(i===2?'支持這句':'推翻這句');
      if(i<2){
       assert((await state()).investigations.progress.records[id].pairs[String(i)][0]===2,'complete index accepted as counterexample');
       await shot(id+'-index-accepted-'+i);
       await click(i===0?'末筆 陳奕廷\n18：10':'首筆 林秀蘭\n17：50');await shot(id+'-focus-'+i);await click('推翻這句');
       assert((await state()).investigations.progress.records[id].pairs[String(i)][0]===(i===0?1:0),'valid pair can be replaced without penalty');
       await click(`換一句 ${i+1}／3`);
      }
     }
     assert((await state()).investigations.ui.page==='pinning','third case finishes on physical record ribbon');
     await shot(id+'-pinning-empty');
     await click('判定 17：50');await shot(id+'-judgment-before-pin');
     assert((await state()).investigations.ui.buttons.find(b=>b.text==='釘上 17：50').disabled,'cannot pin without judgment');
     await click('反駁林秀蘭：\n全在前');await click('釘上 17：50');await shot(id+'-wrong-pin');
     assert((await state()).investigations.ui.buttons.find(b=>b.text==='封存三筆判定').disabled,'wrong player judgment cannot seal');
     await click('拔釘 17：50');await click('反駁陳奕廷：\n全在後');await click('釘上 17：50');
     await click('判定 前後合看');await shot(id+'-support-insufficient');
     assert(!(await state()).investigations.progress.records[id].pin_choices['1'],'18:00 alone cannot support both sides');
     await click('引用 17：50');await shot(id+'-support-one-side');
     assert(!(await state()).investigations.progress.records[id].pin_choices['1'],'single side insufficient');
     await click('已引用 17：50');await click('引用 18：10');await shot(id+'-support-last-only');await click('引用 17：50');await click('支持吳安琪：\n前後都有');await shot(id+'-support-both-sides');await click('釘上 前後合看');await shot(id+'-pinning-last');
     await click('返回街區');await page.waitForTimeout(1800);await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(900);
     assert((await state()).investigations.progress.records[id].pins.join(',')==='0,1','pinned judgments survive disk reload');
     await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);await click((await state()).investigations.ui.buttons.find(b=>b.text.endsWith('｜'+title)).text);await shot(id+'-pinning-reloaded');
     await click('判定 18：10');await click('反駁林秀蘭：\n全在前');await shot(id+'-judgment-chosen');await click('釘上 18：10');await shot(id+'-player-results');
     assert(!(await state()).investigations.progress.records[id].complete,'all judgments need explicit seal');
     assert(JSON.stringify((await state()).investigations.progress.records[id].pin_choices)===JSON.stringify({'0':1,'1':2,'2':0}),'persist exact player choices');
     if(tag==='390x844'){
      const before=(await state()).investigations.progress.records[id];
      await click('拔釘 17：50');await shot(id+'-local-pin-unpinned');
      let local=(await state()).investigations.progress.records[id];
      assert(local.pins.includes(1)&&local.pins.includes(2)&&JSON.stringify(local.support_refs)===JSON.stringify(before.support_refs),'other pins and references retained during local repair');
      await click('反駁林秀蘭：\n全在前');await click('釘上 17：50');await shot(id+'-wrong-pin-with-two-preserved');
      await click('拔釘 17：50');await click('反駁陳奕廷：\n全在後');await click('釘上 17：50');await shot(id+'-local-pin-repaired');
      local=(await state()).investigations.progress.records[id];assert(JSON.stringify(local.pin_choices)===JSON.stringify(before.pin_choices),'local repair restores exact three judgments');
     }
     await click('封存三筆判定');
    }
    await shot(id+'-sealed');s=await state();assert(s.investigations.progress.records[id].complete,'completed '+id);
    assert(s.investigations.ui.visible,'case completion visibly rendered');
    archived[id]=JSON.stringify(s.investigations.progress.records[id]);
    if(tag==='390x844'){await street(id,title,id==='second_help'?0:null);if(id==='second_help'){await street(id,title,1);await street(id,title,2);}await returnToCase(id,title);}
    await click('返回街區');await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(800);assert((await state()).investigations.progress.records[id].complete,'disk load completion');
    await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);
    await click((await state()).investigations.ui.buttons.find(b=>b.text.endsWith('｜'+title)).text);assert(JSON.stringify((await state()).investigations.progress.records[id])===archived[id],'reopened exact player results');await shot(id+'-reopened');await click('案件清單');
    view.checks.push({case:id,status:'VERIFIED',completed:true,saved:true,wrong_retry:true});
   }
   await page.waitForTimeout(1800);await page.reload();await page.locator('#start-button').click();await page.waitForFunction(()=>window.sevenDistrictGame?.phase==='title'&&window.sevenDistrictGame?.world_ready);
   await page.locator('#fullscreen-button').click();await page.waitForTimeout(600);
   await page.evaluate(()=>window.sevenDistrictCommand('load'));await page.waitForTimeout(900);assert(Object.values((await state()).investigations.progress.records).every(r=>r.complete),'all completions survive IndexedDB cold reload');
   await page.evaluate(()=>window.sevenDistrictCommand('investigations'));await page.waitForTimeout(450);await shot('case-list-reloaded');
   for(const [id,title] of [['second_help','第二次求助，第二次收費'],['before_night','晚班之前的收據'],['three_voices','三張嘴，一句真話']]){
    await click((await state()).investigations.ui.buttons.find(b=>b.text.endsWith('｜'+title)).text);assert(JSON.stringify((await state()).investigations.progress.records[id])===archived[id],'cold reload exact player results');await shot(id+'-sealed-reloaded');assert(!(await state()).investigations.ui.buttons.some(b=>/釘上|揭時核對|核對兩處黃標/.test(b.text)),'archive has no mutation controls');await click('證據鏈');await shot(id+'-chain-reloaded');await click('曾選錯');await shot(id+'-history-reloaded');await click('案件清單');
   }
   view.checks.push({indexeddb_cold_reload:'VERIFIED',all_cases_complete:true});view.status='VERIFIED';
  }catch(e){view.status='BLOCKED';view.failure=e.stack;view.failure_state=await state().catch(()=>null);await page.screenshot({path:path.join(out,'debug-failure.png')});report.failures.push({tag,message:e.message});console.log('FAIL',tag,e.message);}
  finally{await context.close();fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(report,null,2)+'\n');}
  if(report.failures.length)break;
 }
 report.status=report.failures.length?'BLOCKED':'VERIFIED';
}finally{if(browser)await browser.close();await new Promise(r=>server.close(r));fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify({status:report.status,views:report.views.length,failures:report.failures}));if(report.failures.length)process.exitCode=1;
