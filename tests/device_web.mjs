// Deterministic shell contract tests. This does not replace real WASM/browser QA.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createEntryDocuments,entryModes,canonicalOrigin,readExportConfig} from '../tools/prepare_web_assets.mjs';
import {inspectEntryDocument,acceptableAssetResponse} from '../tools/verify_web.mjs';
const source = fs.readFileSync(new URL('../web/play-site.js',import.meta.url),'utf8');
const shell = fs.readFileSync(new URL('../web/shell.html',import.meta.url),'utf8');
let checks = 0;
const check = (value,label) => { checks++; assert.ok(value,label); };

class Element {
  constructor(id='') {
    this.id=id; this.hidden=false; this.disabled=false; this.textContent=''; this.value='';
    this.width=1366; this.height=768; this.clientWidth=1000; this.clientHeight=560;
    this.dataset={}; this.style={}; this.attributes={}; this.listeners={};
    const entries = new Set();
    this.classList={ toggle:(key,value)=>value ? entries.add(key) : entries.delete(key),contains:key=>entries.has(key) };
  }
  addEventListener(name,callback) { (this.listeners[name]??=[]).push(callback); }
  emit(name,event={}) { for(const callback of this.listeners[name]||[]) callback(event); }
  setAttribute(key,value) { this.attributes[key]=value; }
  removeAttribute(key) { delete this.attributes[key]; }
  replaceChildren() {}
  append() {}
  focus() { this.focused=true; }
  getBoundingClientRect() { return {width:this.clientWidth,height:this.clientHeight}; }
}

async function boot(options={}) {
  const html=options.html||shell;
  const elements = Object.fromEntries([...html.matchAll(/\bid="([^"]+)"/g)].map(match=>[match[1],new Element(match[1])]));
  elements['godot-config'].textContent=options.html
    ? html.match(/<script\b[^>]*\bid="godot-config"[^>]*>([\s\S]*?)<\/script>/i)[1]
    : JSON.stringify({executable:'/game',fileSizes:{},canvasResizePolicy:0});
  elements['game-frame'].clientWidth=options.width||1000;
  elements['game-frame'].clientHeight=options.height||560;
  const store = options.store||new Map();
  const calls=[];
  const engineConfigs=[];
  const window=new Element('window');
  const document=new Element('document');
  document.body=new Element('body'); document.body.dataset.godotThreads='false';
  document.body.dataset.entryProfile=options.entryProfile||html.match(/\bdata-entry-profile="([^"]+)"/)?.[1]||'auto';
  document.getElementById=id=>elements[id]; document.createElement=()=>new Element(); document.createTextNode=value=>value;
  window.innerWidth=options.screenWidth||1366; window.innerHeight=options.screenHeight||768;
  window.screen={width:window.innerWidth,height:window.innerHeight};
  window.location={pathname:options.path||'/',search:options.search||'',reload:()=>calls.push('reload')};
  window.devicePixelRatio=options.dpr||3;
  window.matchMedia=()=>({matches:options.coarse||false});
  window.localStorage={getItem:key=>store.get(key)??null,setItem:(key,value)=>store.set(key,value)};
  window.getComputedStyle=()=>({paddingLeft:String(options.safeLeft||0),paddingRight:String(options.safeRight||0),paddingTop:'0',paddingBottom:'0'});
  const queued=[]; window.requestAnimationFrame=fn=>queued.push(fn);
  window.sevenDistrictCommand=command=>calls.push(command);
  class MockEngine {
    constructor(config) { engineConfigs.push(config); }
    static getMissingFeatures() { return []; }
    startGame({onProgress}) { onProgress(100,100); return Promise.resolve(); }
  }
  vm.runInNewContext(source,{window,document,navigator:{userAgent:options.ua||'Windows',maxTouchPoints:options.touchPoints||0},Engine:MockEngine,URLSearchParams,console});
  const flush=()=>{ for(let i=0;queued.length&&i<50;i++) queued.shift()(); };
  flush();
  elements['start-button'].emit('click');
  await new Promise(resolve=>setImmediate(resolve));
  flush();
  return {elements,window,document,calls,store,flush,engineConfigs};
}

for(const profile of ['phone','tablet','desktop']) {
  const scene=await boot({path:`/${profile}`,width:800,height:600,dpr:3,safeLeft:20,safeRight:12});
  const expectedCap={phone:1.5,tablet:1.75,desktop:2}[profile];
  check(scene.window.sevenDistrictDevice.profile===profile,`path ${profile} selects real profile`);
  check(scene.elements.canvas.width===Math.round(768*expectedCap) && scene.elements.canvas.height===Math.round(600*expectedCap),`actual backing allocation for ${profile} with safe padding`);
  check(scene.elements.canvas.dataset.pixelRatio===String(expectedCap),`reported backing cap ${profile}`);
  check(scene.document.body.dataset.deviceProfile===profile,`layout selector ${profile}`);
  check(scene.calls.includes(`profile_${profile}`),`fixed backend callback ${profile}`);
  check(Object.isFrozen(scene.window.sevenDistrictDevice),`read only device snapshot ${profile}`);
  const nativeProfiles=JSON.parse(fs.readFileSync(new URL('../godot/data/device_profiles.json',import.meta.url),'utf8'));
  check(scene.window.sevenDistrictDevice.pixel_ratio_cap===nativeProfiles[profile].pixel_ratio_cap,`shell and native ${profile} canvas budgets agree`);
}
const matrix=[
  [360,800,'phone'],[390,844,'phone'],[844,390,'phone'],
  [768,1024,'tablet'],[1024,768,'tablet'],[1280,800,'tablet'],
  [1366,768,'desktop'],[1920,1080,'desktop'],
];
for(const [width,height,profile] of matrix) {
  const scene=await boot({screenWidth:width,screenHeight:height,coarse:profile!=='desktop',ua:profile==='desktop'?'Windows':'Android',width,height});
  check(scene.window.sevenDistrictDevice.profile===profile,`auto matrix ${width}x${height}`);
  check(scene.elements.canvas.width>width && scene.elements.canvas.width<=width*2,`canvas allocation bounded ${width}x${height}`);
  check(scene.elements['touch-hint'].hidden===(profile==='desktop'),`appropriate controls described ${width}x${height}`);
}
const hybrid=await boot({touchPoints:10,coarse:false,ua:'Windows',screenWidth:1366,screenHeight:768});
check(hybrid.window.sevenDistrictDevice.profile==='desktop','hybrid Windows touchscreen does not force phone');
hybrid.elements['device-profile'].value='phone'; hybrid.elements['device-profile'].emit('change'); hybrid.flush();
check(hybrid.window.sevenDistrictDevice.profile==='phone' && hybrid.elements.canvas.width===1500,'manual phone switch changes backing canvas immediately');
check(hybrid.calls.at(-1)==='profile_phone','manual profile uses fixed backend command');
hybrid.elements['device-profile'].value='arbitrary_eval'; hybrid.elements['device-profile'].emit('change');
check(hybrid.window.sevenDistrictDevice.profile==='phone','invalid profile cannot enter bridge');
hybrid.elements['device-profile'].value='auto'; hybrid.elements['device-profile'].emit('change'); hybrid.flush();
check(hybrid.window.sevenDistrictDevice.profile==='desktop','manual auto restores desktop hardware');
const sharedStore=new Map([['seven-district-device-v1:desktop','phone']]);
const savedDesktop=await boot({store:sharedStore});
const independentTablet=await boot({store:sharedStore,coarse:true,ua:'iPad',screenWidth:768,screenHeight:1024});
check(savedDesktop.window.sevenDistrictDevice.profile==='phone','same hardware remembers manual profile');
check(independentTablet.window.sevenDistrictDevice.profile==='tablet','another device class does not inherit desktop manual profile');
const state={phase:'playing',play_started:true,device_profile:'tablet',player_x:1,player_z:2};
hybrid.window.emit('seven-district-state',{detail:state}); hybrid.flush();
check(hybrid.elements['command-jobs'].hidden===false,'delivery button available after actual state bridge contract');
hybrid.elements['command-jobs'].emit('click');
check(hybrid.calls.at(-1)==='jobs','delivery button sends fixed jobs command');
hybrid.window.emit('blur');
check(hybrid.calls.at(-1)==='pause','focus loss pauses movement rather than sticking');
hybrid.document.hidden=true; hybrid.document.emit('visibilitychange');
check(hybrid.calls.at(-1)==='pause','hidden mobile tab requests pause');
check(shell.includes('viewport-fit=cover') && shell.includes('href="/phone"') && shell.includes('href="/tablet"') && shell.includes('href="/desktop"'),'safe area metadata and separate entry links');

for (const [profile,dpr,expected] of [['phone',1.25,1.25],['phone',3,1.5],['tablet',1,1],['tablet',2,1.75],['desktop',1.25,1.25],['desktop',3,2]]) {
  const scene=await boot({path:`/${profile}/`,dpr});
  check(scene.window.sevenDistrictDevice.pixel_ratio===expected && scene.elements.canvas.width===Math.round(1000*expected),`actual ratio ${profile} DPR ${dpr} differs from cap when appropriate`);
}

const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
const hashes={
  'play-site.js':sha(source).slice(0,12),
  'play-site.css':sha(fs.readFileSync(new URL('../web/play-site.css',import.meta.url))).slice(0,12),
  'game.js':sha('official engine fixture').slice(0,12),
};
const version=fs.readFileSync(new URL('../godot/project.godot',import.meta.url),'utf8').match(/^config\/version="([^"]+)"/m)[1];
const exported=shell.replaceAll('$GODOT_PROJECT_NAME','七期：斷鏈行動')
  .replace('$GODOT_HEAD_INCLUDE','<link rel="icon" href="game.icon.png">')
  .replace('$GODOT_THREADS_ENABLED','false')
  .replace('$GODOT_URL','game.js')
  .replace('$GODOT_CONFIG',JSON.stringify({executable:'game',fileSizes:{'game.wasm':200,'game.pck':124},canvasResizePolicy:0,gdextensionLibs:[]}));
const docs=createEntryDocuments(exported,{version,hashes});
const build={version,canonical_origin:canonicalOrigin,asset_hashes:hashes,wasm_original_bytes:200,files:[{name:'game.pck',bytes:124}]};
check(new Set(entryModes.map(entry=>docs[entry.document])).size===4,'all four entry documents have distinct launch content');
for (const entry of entryModes) {
  const html=docs[entry.document], config=readExportConfig(html);
  check(inspectEntryDocument(html,entry,build).every(result=>result.passed),`${entry.route} has complete static launch contract`);
  check(config.executable==='/game' && config.mainPack==='/game.pck' && config.fileSizes['/game.wasm']===200 && config.fileSizes['/game.pck']===124,`${entry.route} loads shared root binary assets`);
  const scene=await boot({html,path:entry.route});
  const expected=entry.profile==='auto'?'desktop':entry.profile;
  check(scene.window.sevenDistrictDevice.profile===expected && scene.calls.includes(`profile_${entry.profile}`),`${entry.route} reaches fixed profile callback through startup`);
  check(scene.engineConfigs[0].executable==='/game' && scene.engineConfigs[0].mainPack==='/game.pck' && scene.engineConfigs[0].canvasResizePolicy===0,`${entry.route} passes rooted engine configuration into Engine API`);
}
const routed=await boot({html:docs['phone/index.html'],path:'/phone/',search:'?profile=tablet',store:new Map([['seven-district-device-v1:desktop','desktop']])});
check(routed.window.sevenDistrictDevice.profile==='tablet' && routed.calls.includes('profile_tablet'),'explicit query override works without copying game or inherited desktop preference');
const hinted=await boot({html:docs['tablet/index.html'],path:'/tablet/index.html'});
check(hinted.window.sevenDistrictDevice.profile==='tablet','generated entry metadata and alias preserve tablet startup');
check(Object.keys(docs).filter(name=>name.endsWith('.html')).length===5 && docs['game.html']===docs['index.html'],'root alias shares auto HTML while three device files remain independent');
for (const [label,mutate] of [
  ['nested executable',html=>html.replace('"executable":"/game"','"executable":"/phone/game"')],
  ['stale script hash',html=>html.replace(`play-site.js?v=${hashes['play-site.js']}`,'play-site.js?v=000000000000')],
  ['relative engine script',html=>html.replace('src="/game.js','src="game.js')],
  ['wrong entry profile',html=>html.replace('data-entry-profile="phone"','data-entry-profile="desktop"')],
  ['wrong pack load size',html=>html.replace('"/game.pck":124','"/game.pck":999')],
  ['old build version',html=>html.replace(`data-build-version="${version}"`,'data-build-version="0.3.0"')],
]) {
  check(inspectEntryDocument(mutate(docs['phone/index.html']),entryModes[1],build).some(result=>!result.passed),`verifier rejects ${label}`);
}
assert.throws(()=>createEntryDocuments(exported,{version:'not-a-version',hashes}),/real project version/); checks++;
assert.throws(()=>createEntryDocuments(exported.replace('"fileSizes":','"wrongSizes":'),{version,hashes}),/configuration/); checks++;
assert.throws(()=>createEntryDocuments(exported,{version,hashes:{...hashes,'play-site.js':'invalid'}}),/Content hash/); checks++;
assert.throws(()=>createEntryDocuments(exported.replace('"executable":"game"','"executable":"phone/game"'),{version,hashes}),/shared \/game engine/); checks++;
assert.throws(()=>createEntryDocuments(exported.replace('"game.pck":124','"game.pck":-124'),{version,hashes}),/positive file sizes/); checks++;
const wasm=Buffer.from([0,97,115,109,1,0,0,0]);
const wasmManifest={wasm_asset:'game.wasm.br',wasm_original_sha256:sha(wasm)};
const response=(type,encoding)=>({ok:true,headers:new Map([['content-type',type],['content-encoding',encoding]])});
check(acceptableAssetResponse({name:'game.wasm.br'},response('application/wasm','br'),wasm,wasmManifest),'decoded WASM requires real magic, correct MIME and Brotli transport');
check(!acceptableAssetResponse({name:'game.wasm.br'},response('application/wasm',null),wasm,wasmManifest),'missing encoding is rejected even if decoded bytes match');
const htmlError=Buffer.from('<!doctype html><html>街區入口沒有開放</html>');
check(!acceptableAssetResponse({name:'game.wasm.br'},response('text/html','br'),htmlError,{...wasmManifest,wasm_original_sha256:sha(htmlError)}),'HTML fallback cannot masquerade as a WASM asset even with matching hash');
check(!acceptableAssetResponse({name:'game.js',sha256:sha(htmlError)},response('text/html'),htmlError,wasmManifest),'HTML fallback cannot masquerade as engine JavaScript');
const pack=Buffer.from('GDPC: real package contract');
check(!acceptableAssetResponse({name:'game.pck',sha256:sha(pack)},response('text/html'),pack,wasmManifest),'pack MIME must be binary instead of HTML');
console.log(`DEVICE_WEB_CHECKS=${checks} FAILURES=0`);
