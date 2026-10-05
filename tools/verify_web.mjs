// Verify each deployed entry and its shared assets; this is HTTP evidence, not browser rendering QA.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {readExportConfig} from './prepare_web_assets.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const hash = data => crypto.createHash('sha256').update(data).digest('hex');

export function inspectEntryDocument(html, entry, manifest) {
  const checks=[];
  const check=(name,passed)=>checks.push({file:`${entry.route} ${name}`,passed:Boolean(passed)});
  check('HTML document',/^\s*<!doctype html>/i.test(html));
  check('actual project version',html.includes(`data-build-version="${manifest.version}"`) && html.includes(`Alpha ${manifest.version.split('.').slice(0,2).join('.')}`));
  check('independent profile',html.includes(`data-entry-profile="${entry.profile}"`) && html.includes(`<option value="${entry.profile}" selected>`));
  check('entry title and instructions',html.includes(entry.title) && html.includes(entry.hint));
  check('canonical link',html.includes(`rel="canonical" href="${new URL(entry.route,manifest.canonical_origin)}"`));
  for (const name of ['play-site.css','play-site.js','game.js']) {
    check(`${name} root URL and content hash`,html.includes(`"/${name}?v=${manifest.asset_hashes?.[name]}"`));
  }
  const assets=[...html.matchAll(/<(?:script|link)\b[^>]*\b(?:src|href)="([^"]+)"[^>]*>/gi)].map(match=>match[1]);
  check('no route-relative engine/stylesheet/icon resources',assets.every(value=>value.startsWith('/') || /^https:\/\//.test(value)));
  try {
    const config=readExportConfig(html);
    const pack=manifest.files.find(file=>file.name==='game.pck');
    check('shared executable and pack',config.executable==='/game' && config.mainPack==='/game.pck');
    check('absolute load sizes',config.fileSizes['/game.wasm']===manifest.wasm_original_bytes && config.fileSizes['/game.pck']===pack?.bytes && Object.keys(config.fileSizes).every(name=>name.startsWith('/')));
    check('single-threaded page contract',html.includes('data-godot-threads="false"') && config.canvasResizePolicy===0);
  } catch (error) {
    checks.push({file:`${entry.route} Godot configuration`,passed:false,error:error.message});
  }
  return checks;
}

export function acceptableAssetResponse(file, response, data, manifest) {
  const wasm=file.name===manifest.wasm_asset;
  const expected=wasm?manifest.wasm_original_sha256:file.sha256;
  if (!response.ok || hash(data)!==expected) return false;
  const mime=response.headers.get('content-type')||'';
  if (wasm) return data.subarray(0,4).equals(Buffer.from([0,97,115,109])) && response.headers.get('content-encoding')==='br' && mime.includes('application/wasm');
  if (file.name.endsWith('.pck')) return mime.includes('application/octet-stream') && data.subarray(0,4).toString()==='GDPC';
  if (file.name.endsWith('.js')) return /(?:java|ecma)script/i.test(mime) && !/^\s*<(?:!doctype|html)/i.test(data.toString('utf8',0,80));
  if (file.name.endsWith('.css')) return mime.includes('text/css');
  if (file.name.endsWith('.html')) return mime.includes('text/html');
  return true;
}

export async function verifyWeb(baseUrl, reportPath='qa/web-deployment.json', manifestPath='qa/web-build.json') {
  const origin=new URL('/',baseUrl);
  const manifest=JSON.parse(fs.readFileSync(path.resolve(root,manifestPath),'utf8'));
  if (!Array.isArray(manifest.entrypoints) || manifest.entrypoints.map(entry=>entry.profile).join(',')!=='auto,phone,tablet,desktop') throw new Error('Rebuild first: the four actual device entries are absent from the manifest');
  const files=manifest.files.filter(file=>!['_headers','_redirects'].includes(file.name));
  const checks=new Array(files.length);
  let next=0;
  const htmlByFile=new Map();
  await Promise.all(Array.from({length:4},async()=>{
    while(next<files.length) {
      const index=next++, file=files[index];
      try {
        const wasm=file.name===manifest.wasm_asset;
        const entry=manifest.entrypoints.find(entry=>entry.document===file.name);
        const resource=entry?entry.route:wasm?manifest.wasm_url:file.name;
        const response=await fetch(new URL(resource,origin),{signal:AbortSignal.timeout(60000)});
        const data=Buffer.from(await response.arrayBuffer());
        if (file.name.endsWith('.html')) htmlByFile.set(file.name,data.toString('utf8'));
        checks[index]={file:file.name,url:new URL(resource,origin).pathname,status:response.status,passed:acceptableAssetResponse(file,response,data,manifest),decoded_bytes:data.length,content_type:response.headers.get('content-type'),content_encoding:response.headers.get('content-encoding')};
      } catch(error) { checks[index]={file:file.name,passed:false,error:error.message}; }
    }
  }));
  for (const entry of manifest.entrypoints) checks.push(...inspectEntryDocument(htmlByFile.get(entry.document)||'',entry,manifest));
  const documents=manifest.entrypoints.map(entry=>htmlByFile.get(entry.document));
  checks.push({file:'independent HTML documents',passed:documents.every(Boolean) && new Set(documents).size===4});
  const aliases=[['/index.html','/'],['/game.html','/'],...manifest.entrypoints.filter(entry=>entry.profile!=='auto').flatMap(entry=>[[entry.route.slice(0,-1),entry.route],[`/${entry.document}`,entry.route]])];
  for (const [alias,canonical] of aliases) {
    try {
      const response=await fetch(new URL(alias,origin),{redirect:'manual',signal:AbortSignal.timeout(15000)});
      const location=response.headers.get('location');
      checks.push({file:`canonical redirect ${alias}`,status:response.status,location,passed:[301,302,307,308].includes(response.status) && location && new URL(location,origin).pathname===canonical});
      await response.arrayBuffer();
    } catch(error) { checks.push({file:`canonical redirect ${alias}`,passed:false,error:error.message}); }
  }
  for (const missingPath of ['/missing-web-verification-0.4','/phone/game.wasm','/tablet/game.pck','/desktop/game.js']) {
    try {
      const response=await fetch(new URL(missingPath,origin),{signal:AbortSignal.timeout(15000)});
      const data=await response.text();
      checks.push({file:`missing route ${missingPath}`,status:response.status,passed:response.status===404 && response.headers.get('content-type')?.includes('text/html') && data.includes('街區')});
    } catch(error) { checks.push({file:`missing route ${missingPath}`,passed:false,error:error.message}); }
  }
  const result={version:manifest.version,url:origin.origin,verified_at:new Date().toISOString(),scope:'static HTTP bytes, MIME, decoded engine, entry configuration and redirects; no browser/FPS claim',status:checks.every(check=>check.passed)?'PASS':'FAIL',checks};
  fs.writeFileSync(path.resolve(root,reportPath),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify({status:result.status,url:result.url,checks:checks.length,failures:checks.filter(check=>!check.passed)}));
  return result;
}

if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const result=await verifyWeb(process.argv[2]||'http://127.0.0.1:8766',process.argv[3]||'qa/web-deployment.json',process.argv[4]||'qa/web-build.json');
  if(result.status!=='PASS') process.exitCode=1;
}
