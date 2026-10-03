// Verify a deployed static package against the build manifest, including decoded WASM.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const origin = new URL(process.argv[2] || 'http://127.0.0.1:8766');
const manifest = JSON.parse(fs.readFileSync(path.join(root,'qa/web-build.json'),'utf8'));
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const files = manifest.files.filter(file => file.name !== '_headers');
async function verifyFile(file) {
  const wasm = file.name === manifest.wasm_asset;
  const url = new URL(file.name === 'index.html' ? '/' : wasm ? manifest.wasm_url : file.name,origin);
  const response = await fetch(url,{signal:AbortSignal.timeout(60000)});
  const data = Buffer.from(await response.arrayBuffer());
  const expected = wasm ? manifest.wasm_original_sha256 : file.sha256;
  const passed = response.ok && hash(data) === expected && (!wasm || (data.subarray(0,4).equals(Buffer.from([0,97,115,109])) && response.headers.get('content-encoding') === 'br' && response.headers.get('content-type')?.includes('application/wasm')));
  return {file:file.name,status:response.status,passed,decoded_bytes:data.length,content_type:response.headers.get('content-type'),content_encoding:response.headers.get('content-encoding')};
}
const checks = new Array(files.length);
let next = 0;
await Promise.all(Array.from({length:4},async () => {
  while (next < files.length) {
    const index = next++;
    try { checks[index] = await verifyFile(files[index]); }
    catch (error) { checks[index] = {file:files[index].name,passed:false,error:error.message}; }
  }
}));
const missing = await fetch(new URL('/missing-web-verification-0.2',origin));
const missingText = await missing.text();
checks.push({file:'404 route',status:missing.status,passed:missing.status === 404 && missingText.includes('街區')});
const result = {version:manifest.version,url:origin.origin,verified_at:new Date().toISOString(),status:checks.every(check=>check.passed)?'PASS':'FAIL',checks};
fs.writeFileSync(path.resolve(root,process.argv[3] || 'qa/web-deployment.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({status:result.status,url:result.url,checks:checks.length,failures:checks.filter(check=>!check.passed)}));
if(result.status !== 'PASS') process.exitCode=1;
