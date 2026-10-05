import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const canonicalOrigin = 'https://seven-district-reckoning.digimkt.workers.dev';
export const entryModes = Object.freeze([
  Object.freeze({profile:'auto', route:'/', document:'index.html', label:'自動選擇', title:'線上遊玩', hint:'依裝置選擇操作與畫面，也可手動切換手機、平板或電腦。'}),
  Object.freeze({profile:'phone', route:'/phone/', document:'phone/index.html', label:'手機', title:'手機版', hint:'左下浮動搖桿移動，右側點按動作。直向可玩，橫向放大可看更遠。'}),
  Object.freeze({profile:'tablet', route:'/tablet/', document:'tablet/index.html', label:'平板', title:'平板版', hint:'較大的觸控鍵、雙欄生活任務與大地圖。可直向查看任務，再橫向騎車。'}),
  Object.freeze({profile:'desktop', route:'/desktop/', document:'desktop/index.html', label:'電腦', title:'電腦版', hint:'WASD 移動、右鍵拖曳視角；J 外送與取貨、M 地圖、Tab 委託。'}),
]);

const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const shortVersion = version => version.split('.').slice(0,2).join('.');
const rootUrl = value => /^(?:[a-z][a-z0-9+.-]*:|\/|#)/i.test(value) ? value : '/' + value.replace(/^\.\//,'');

export function readExportConfig(html) {
  const block = html.match(/<script\b[^>]*\bid="godot-config"[^>]*>([\s\S]*?)<\/script>/i);
  if (!block) throw new Error('The exported Godot configuration is missing');
  const config = JSON.parse(block[1]);
  if (!config.executable || !config.fileSizes || !Object.keys(config.fileSizes).some(name=>name.endsWith('.pck')) || !Object.keys(config.fileSizes).some(name=>name.endsWith('.wasm'))) {
    throw new Error('Expected an official Godot executable, PCK and WASM configuration');
  }
  return config;
}

// All entry documents share one engine and package at the origin root. The route
// chooses an actual device profile; it never relocates or duplicates game assets.
export function createEntryDocuments(exportedHtml, {version, hashes, origin=canonicalOrigin}={}) {
  if (!/^\d+\.\d+\.\d+(?:[-+][\w.-]+)?$/.test(version||'')) throw new Error('A real project version is required');
  const config = readExportConfig(exportedHtml);
  config.executable = rootUrl(config.executable);
  config.mainPack = rootUrl(config.mainPack || `${config.executable}.pck`);
  config.fileSizes = Object.fromEntries(Object.entries(config.fileSizes).map(([name,size])=>[rootUrl(name),size]));
  if (config.executable!=='/game' || config.mainPack!=='/game.pck' || !Object.values(config.fileSizes).every(size=>Number.isSafeInteger(size) && size>0)) {
    throw new Error('All entries require the shared /game engine with positive file sizes');
  }
  if (Array.isArray(config.gdextensionLibs)) config.gdextensionLibs=config.gdextensionLibs.map(rootUrl);
  let base = exportedHtml.replace(/(<script\b[^>]*\bid="godot-config"[^>]*>)[\s\S]*?(<\/script>)/i,
    (_,open,close)=>open+JSON.stringify(config).replaceAll('<','\\u003c')+close);
  base = base.replace(/\b(src|href)="([^"]+)"/g, (_,attribute,value)=>`${attribute}="${rootUrl(value)}"`);
  for (const name of ['play-site.css','play-site.js','game.js']) {
    if (!/^[a-f0-9]{12}$/.test(hashes?.[name]||'')) throw new Error(`Content hash required for ${name}`);
    const pattern = new RegExp(`(["'])/${name.replaceAll('.','\\.')}(?:\\?[^"']*)?(["'])`,'g');
    base = base.replace(pattern, `$1/${name}?v=${hashes[name]}$2`);
  }
  base = base.replace(/<link\b[^>]*\brel="canonical"[^>]*>\s*/gi,'');
  base = base.replace(/ALPHA\s+\d+\.\d+(?:\.\d+)?/g, `ALPHA ${shortVersion(version)}`);
  const title = base.match(/<title>([\s\S]*?)<\/title>/i)?.[1]?.split('｜')[0];
  if (!title || !base.includes('id="device-entry-hint"')) throw new Error('Use the current device-entry shell before preparing the export');
  const documents = {};
  for (const entry of entryModes) {
    let html = base.replace(/<title>[\s\S]*?<\/title>/i,`<title>${title}｜Alpha ${shortVersion(version)} ${entry.title}</title>\n  <link rel="canonical" href="${new URL(entry.route,origin)}">`);
    html = html.replace(/<body\b([^>]*)>/i,(_,attributes)=>{
      const preserved=attributes.replace(/\sdata-(?:entry-profile|device-profile|build-version)="[^"]*"/g,'');
      return `<body${preserved} data-entry-profile="${entry.profile}" data-device-profile="${entry.profile}" data-build-version="${version}">`;
    });
    html = html.replace(/(<p\b[^>]*\bid="device-entry-hint"[^>]*>)[\s\S]*?(<\/p>)/i,(_,open,close)=>open+entry.hint+close);
    html = html.replace(/(<span\b[^>]*\bid="device-entry-title"[^>]*>)[\s\S]*?(<\/span>)/i,(_,open,close)=>open+entry.title+close);
    html = html.replace(/<option value="(auto|phone|tablet|desktop)"(?: selected)?>/g,(_,profile)=>`<option value="${profile}"${profile===entry.profile?' selected':''}>`);
    documents[entry.document]=html;
  }
  documents['game.html']=documents['index.html'];
  return documents;
}

export function prepareWebAssets(output=path.join(root,'deliverables','web'), {manifestPath=path.join(root,'qa/web-build.json')}={}) {
  const project = fs.readFileSync(path.join(root,'godot/project.godot'),'utf8');
  const version = project.match(/^config\/version="([^"]+)"/m)?.[1];
  if (!version) throw new Error('Project version is missing');
  const exportedHtml = fs.readFileSync(path.join(output,'game.html'),'utf8');
  const exportedConfig=readExportConfig(exportedHtml);
  const wasmPath = path.join(output,'game.wasm');
  const raw = fs.readFileSync(wasmPath);
  if (!raw.subarray(0,4).equals(Buffer.from([0,97,115,109]))) throw new Error('Expected raw official WASM before compression. Re-export first.');
  for (const name of ['game.js','game.pck']) if (!fs.statSync(path.join(output,name)).isFile()) throw new Error(`Exported ${name} is missing`);
  const exportedSizes=Object.fromEntries(Object.entries(exportedConfig.fileSizes).map(([name,size])=>[rootUrl(name),size]));
  if (exportedSizes['/game.wasm']!==raw.length || exportedSizes['/game.pck']!==fs.statSync(path.join(output,'game.pck')).size) throw new Error('The exported HTML and binary payload sizes do not match; re-export the whole package');
  const packed = zlib.brotliCompressSync(raw,{params:{[zlib.constants.BROTLI_PARAM_QUALITY]:8}});
  if (packed.length > 25*1024*1024) throw new Error('Compressed asset exceeds hosting cap');
  for (const name of ['play-site.css','play-site.js','404.html']) fs.copyFileSync(path.join(root,'web',name),path.join(output,name));
  const hashes = Object.fromEntries(['play-site.css','play-site.js','game.js'].map(name=>[name,hash(fs.readFileSync(path.join(output,name))).slice(0,12)]));
  const documents = createEntryDocuments(exportedHtml,{version,hashes});
  for (const [name,html] of Object.entries(documents)) {
    fs.mkdirSync(path.dirname(path.join(output,name)),{recursive:true});
    fs.writeFileSync(path.join(output,name),html);
  }
  // The 404 page lives at the root even when the requested URL was nested.
  const notFound = fs.readFileSync(path.join(output,'404.html'),'utf8').replace(/href="(?:\/)?play-site\.css(?:\?[^"\s]*)?"/g,`href="/play-site.css?v=${hashes['play-site.css']}"`);
  fs.writeFileSync(path.join(output,'404.html'),notFound);
  fs.writeFileSync(wasmPath+'.br',packed);
  fs.unlinkSync(wasmPath);
  fs.copyFileSync(path.join(root,'godot/assets/icon.svg'),path.join(output,'favicon.svg'));
  for (const name of ['LICENSE','CREDITS.md','LICENSE-ASSETS.md']) fs.copyFileSync(path.join(root,name),path.join(output,name==='LICENSE'?'LICENSE.txt':name.replace('.md','.txt')));
  fs.mkdirSync(path.join(output,'licenses'),{recursive:true});
  for (const name of ['Godot-LICENSE.txt','Godot-COPYRIGHT.txt','CC-BY-3.0.txt','car-kit-License.txt','city-kit-commercial-License.txt','city-kit-roads-License.txt','mini-characters-License.txt','furniture-kit-License.txt','nature-kit-License.txt']) fs.copyFileSync(path.join(root,'assets/provenance',name),path.join(output,'licenses',name));
  fs.copyFileSync(path.join(root,'godot/assets/fonts/OFL.txt'),path.join(output,'licenses/OFL.txt'));
  fs.copyFileSync(path.join(root,'assets/provenance/v03-urban-CC0.txt'),path.join(output,'licenses/urban-CC0.txt'));
  fs.copyFileSync(path.join(root,'assets/source/makehuman/LICENSE.ASSETS.md'),path.join(output,'licenses/MakeHuman-ASSETS-CC0.txt'));
  fs.copyFileSync(path.join(root,'assets/provenance/v03-human-assets.md'),path.join(output,'licenses/MakeHuman-source-notice.txt'));
  fs.copyFileSync(path.join(root,'assets/provenance/v04-taiwan-CC0.txt'),path.join(output,'licenses/taiwan-CC0.txt'));
  fs.writeFileSync(path.join(output,'_headers'),`/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
/game.wasm
  Content-Type: application/wasm
  Content-Encoding: br
  Cache-Control: public, max-age=0, must-revalidate
/*.pck
  Content-Type: application/octet-stream
  Cache-Control: public, max-age=0, must-revalidate
/*.html
  Cache-Control: public, max-age=0, must-revalidate
/
  Cache-Control: public, max-age=0, must-revalidate
/phone/
  Cache-Control: public, max-age=0, must-revalidate
/tablet/
  Cache-Control: public, max-age=0, must-revalidate
/desktop/
  Cache-Control: public, max-age=0, must-revalidate
`);
  fs.writeFileSync(path.join(output,'_redirects'),`/index.html / 301
/game.html / 301
/phone /phone/ 301
/tablet /tablet/ 301
/desktop /desktop/ 301
/phone/index.html /phone/ 301
/tablet/index.html /tablet/ 301
/desktop/index.html /desktop/ 301
`);
  fs.writeFileSync(path.join(output,'robots.txt'),'User-agent: *\nAllow: /\n');
  const profiles=JSON.parse(fs.readFileSync(path.join(root,'godot/data/device_profiles.json'),'utf8'));
  const manifest = {version,canonical_origin:canonicalOrigin,entrypoints:entryModes.map(entry=>({...entry,settings:entry.profile==='auto'?null:profiles[entry.profile]})),asset_hashes:hashes,wasm_asset:'game.wasm.br',wasm_url:'/game.wasm',wasm_original_bytes:raw.length,wasm_transfer_bytes:packed.length,wasm_original_sha256:hash(raw),files:[]};
  for (const name of fs.readdirSync(output,{recursive:true}).sort()) {
    const file=path.join(output,name); if (!fs.statSync(file).isFile()) continue;
    const data=fs.readFileSync(file); if (data.length>25*1024*1024) throw new Error(`Oversized asset: ${name}`);
    manifest.files.push({name:name.split(path.sep).join('/'),bytes:data.length,sha256:hash(data)});
  }
  fs.mkdirSync(path.dirname(path.resolve(manifestPath)),{recursive:true});
  fs.writeFileSync(path.resolve(manifestPath),JSON.stringify(manifest,null,2)+'\n');
  console.log(JSON.stringify({version,original_wasm:raw.length,compressed_wasm:packed.length,files:manifest.files.length,entrypoints:manifest.entrypoints.map(entry=>entry.route)}));
  return manifest;
}

if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) prepareWebAssets();
