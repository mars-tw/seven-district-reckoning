// Local-only rendered WebGL evidence. This script never opens a visible window.
// Usage: node tools/r2_mobile_evidence.mjs --web-dir <export> --phase before|after
//        --playwright-module <installed playwright or playwright-core module>
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import {createRequire} from 'node:module';
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs,v,i,a)=>i%2 ? pairs : [...pairs,[v.slice(2),a[i+1]]],[]));
if (!args['web-dir'] || !['before','after'].includes(args.phase)) throw new Error('Explicit local web-dir and phase required');
const require = createRequire(import.meta.url);
const {chromium} = require(args['playwright-module'] || 'playwright');
const directory = path.resolve(args['web-dir']);
const output = path.resolve(args.output || `docs/evidence/r2-mobile/${args.phase}`);
fs.mkdirSync(output,{recursive:true});
const server = http.createServer((req,res)=>{
  let name = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if (name.endsWith('/')) name += 'index.html';
  const wasm = name === '/game.wasm';
  const file = path.resolve(directory,'.'+name+(wasm?'.br':''));
  if (!file.startsWith(directory+path.sep) || !fs.existsSync(file)) {res.writeHead(404);res.end();return;}
  const mime = {'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.css':'text/css','.png':'image/png','.svg':'image/svg+xml'};
  res.setHeader('Content-Type',wasm?'application/wasm':mime[path.extname(file)]||'application/octet-stream');
  if(wasm) res.setHeader('Content-Encoding','br');
  fs.createReadStream(file).pipe(res);
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
let browser;
const evidence = {phase:args.phase,status:'EXECUTED',environment:'並發載量測，僅供參考',rendering:'Actual Godot WebGL canvas in headless Chromium with SwiftShader software rendering; frame intervals are not hardware GPU execution times or phone hardware results.',views:[]};
if(args.view && fs.existsSync(path.join(output,'rendered-evidence.json'))) {
  evidence.views=JSON.parse(fs.readFileSync(path.join(output,'rendered-evidence.json'),'utf8')).views.filter(v=>(v.viewport.width<900?'phone':'desktop')!==args.view);
}
try {
  browser = await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
  for (const [width,height,profile] of [[390,844,'phone'],[844,390,'phone'],[1366,600,'desktop']]) {
    if(args.view && profile!==args.view) continue;
    console.log(`CAPTURE ${args.phase} ${width}x${height}`);
    const context = await browser.newContext({viewport:{width,height},deviceScaleFactor:1,hasTouch:profile==='phone',isMobile:profile==='phone'});
    const page = await context.newPage();
    page.setDefaultTimeout(180000);
    const logs=[];
    page.on('console',msg=>{if(['error','warning'].includes(msg.type())) logs.push(`${msg.type()}: ${msg.text()}`);});
    page.on('pageerror',e=>logs.push(`pageerror: ${e.message}`));
    await page.addInitScript(()=>{
      window.__renderCalls = 0;
      for (const cls of [window.WebGLRenderingContext,window.WebGL2RenderingContext]) {
        if(!cls) continue;
        for (const name of ['drawArrays','drawElements','drawArraysInstanced','drawElementsInstanced']) {
          const original=cls.prototype[name];
          if(!original) continue;
          cls.prototype[name]=function(...args){window.__renderCalls++;return original.apply(this,args);};
        }
      }
    });
    await page.goto(`${origin}/${profile}/`);
    await page.locator('#start-button').click();
    await page.waitForFunction(()=>typeof window.sevenDistrictCommand === 'function' && window.sevenDistrictGame?.phase === 'title');
    await page.locator('#fullscreen-button').click();
    await page.waitForTimeout(1200);
    const canvas=await page.locator('#canvas').boundingBox();
    if(Math.abs(canvas.width-width)>2 || Math.abs(canvas.height-height)>2) throw new Error('Canvas does not fill requested viewport');
    await page.screenshot({path:path.join(output,`${width}x${height}-title.png`)});
    await page.evaluate(()=>window.sevenDistrictCommand('new_game'));
    await page.waitForTimeout(800);
    await page.mouse.click(width-64,40); // The real story's fixed skip button.
    await page.waitForFunction(()=>window.sevenDistrictGame?.phase === 'playing');
    await page.waitForTimeout(10000); // Warm-up and remove the mission banner.
    await page.screenshot({path:path.join(output,`${width}x${height}-gameplay.png`)});
    const state = await page.evaluate(()=>({...window.sevenDistrictGame}));
    if(!(state.draw_calls>0) || !(await page.evaluate(()=>window.__renderCalls>0))) throw new Error('No real WebGL drawing observed');
    const view={viewport:{width,height},canvas,state,logs,runs:[]};
    if(args.phase==='after') {
      for(let run=0;run<3;run++) {
        const intervals=await page.evaluate(()=>new Promise(resolve=>{
          const values=[];let previous=0,lastCalls=window.__renderCalls;
          const sample=t=>{
            const calls=window.__renderCalls;
            if(calls>lastCalls && previous>0) values.push(t-previous);
            if(calls>lastCalls) previous=t;
            lastCalls=calls;
            if(values.length>=90) resolve(values); else requestAnimationFrame(sample);
          };requestAnimationFrame(sample);
        }));
        const sorted=[...intervals].sort((a,b)=>a-b);
        const percentile=p=>sorted[Math.ceil(sorted.length*p)-1];
        view.runs.push({samples:intervals.length,p50_ms:percentile(.5),p95_ms:percentile(.95),p99_ms:percentile(.99),intervals_ms:intervals});
      }
      view.median_p95_ms=view.runs.map(v=>v.p95_ms).sort((a,b)=>a-b)[1];
      view.webgl=await page.evaluate(()=>{
        const gl=document.getElementById('canvas').getContext('webgl2');
        const info=gl.getExtension('WEBGL_debug_renderer_info');
        return {renderer:info?gl.getParameter(info.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),version:gl.getParameter(gl.VERSION)};
      });
    }
    await page.evaluate(()=>window.sevenDistrictCommand('pause'));
    await page.waitForTimeout(800);
    await page.screenshot({path:path.join(output,`${width}x${height}-pause.png`)});
    if(args.phase==='after') {
      await page.evaluate(()=>window.sevenDistrictCommand('revisits'));
      await page.waitForTimeout(800);
      await page.screenshot({path:path.join(output,`${width}x${height}-revisits.png`)});
    }
    evidence.views.push(view);
    fs.writeFileSync(path.join(output,'rendered-evidence.json'),JSON.stringify(evidence,null,2)+'\n');
    if(args.phase==='after' && logs.some(line=>line.startsWith('error:') || line.startsWith('pageerror:'))) throw new Error('Rendered build produced browser errors; inspect evidence logs');
    await context.close();
  }
  evidence.status='VERIFIED';
} finally {
  fs.writeFileSync(path.join(output,'rendered-evidence.json'),JSON.stringify(evidence,null,2)+'\n');
  await browser?.close();
  await new Promise(resolve=>server.close(resolve));
}
console.log(`EVIDENCE ${evidence.status} views=${evidence.views.length}`);
