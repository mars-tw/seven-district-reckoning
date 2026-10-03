import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'deliverables', 'web');
const wasmPath = path.join(out, 'game.wasm');
const raw = fs.readFileSync(wasmPath);
if (!raw.subarray(0, 4).equals(Buffer.from([0,97,115,109]))) throw new Error('Expected raw official WASM before compression. Re-export first.');
const packed = zlib.brotliCompressSync(raw, {params:{[zlib.constants.BROTLI_PARAM_QUALITY]:8}});
if (packed.length > 25 * 1024 * 1024) throw new Error('Compressed asset exceeds hosting cap');
fs.writeFileSync(wasmPath + '.br', packed);
fs.unlinkSync(wasmPath);
for (const name of ['play-site.css','play-site.js','404.html']) fs.copyFileSync(path.join(root,'web',name),path.join(out,name));
const digest = name => crypto.createHash('sha256').update(fs.readFileSync(path.join(out,name))).digest('hex').slice(0,12);
let html = fs.readFileSync(path.join(out,'game.html'),'utf8');
for (const name of ['play-site.css','play-site.js']) html = html.replaceAll(`"${name}"`, `"${name}?v=${digest(name)}"`);
for (const name of ['game.html','index.html']) fs.writeFileSync(path.join(out,name),html);
fs.copyFileSync(path.join(root,'godot/assets/icon.svg'),path.join(out,'favicon.svg'));
for (const name of ['LICENSE','CREDITS.md','LICENSE-ASSETS.md']) fs.copyFileSync(path.join(root,name),path.join(out,name === 'LICENSE' ? 'LICENSE.txt' : name.replace('.md','.txt')));
fs.mkdirSync(path.join(out,'licenses'),{recursive:true});
for (const name of ['Godot-LICENSE.txt','Godot-COPYRIGHT.txt','CC-BY-3.0.txt','car-kit-License.txt','city-kit-commercial-License.txt','city-kit-roads-License.txt','mini-characters-License.txt','furniture-kit-License.txt','nature-kit-License.txt']) fs.copyFileSync(path.join(root,'assets/provenance',name),path.join(out,'licenses',name));
fs.copyFileSync(path.join(root,'godot/assets/fonts/OFL.txt'),path.join(out,'licenses/OFL.txt'));
fs.writeFileSync(path.join(out,'_headers'),`/*
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
`);
fs.writeFileSync(path.join(out,'robots.txt'),'User-agent: *\nAllow: /\n');
const manifest = {version:'0.2.0',wasm_asset:'game.wasm.br',wasm_url:'game.wasm',wasm_original_bytes:raw.length,wasm_transfer_bytes:packed.length,wasm_original_sha256:crypto.createHash('sha256').update(raw).digest('hex'), files:[]};
for(const name of fs.readdirSync(out,{recursive:true})){
  const p=path.join(out,name); if(!fs.statSync(p).isFile())continue;
  const data=fs.readFileSync(p); if(data.length>25*1024*1024)throw new Error(`Oversized asset: ${name}`);
  manifest.files.push({name:name.split(path.sep).join('/'),bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')});
}
fs.writeFileSync(path.join(root,'qa','web-build.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({original_wasm:raw.length,compressed_wasm:packed.length,files:manifest.files.length}));
