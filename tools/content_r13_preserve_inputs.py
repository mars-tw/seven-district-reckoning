"""Preserve historical verifier inputs referenced dynamically by old manifests."""
import hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r13'
AUDIT=ROOT/'.audit-tmp/content-r13'
report=json.loads((OUT/'cleanup.json').read_text(encoding='utf8'))
assert Path.cwd().resolve()==ROOT.resolve()
protected=json.loads((AUDIT/'ownership.json').read_text(encoding='utf8'))['protected']
receipts={e['path']:e for e in report['deleted']}
references={}
def walk(value,parent,origin):
 if isinstance(value,dict):
  for child in value.values():walk(child,parent,origin)
 elif isinstance(value,list):
  for child in value:walk(child,parent,origin)
 elif isinstance(value,str) and Path(value).suffix.lower() in ['.png','.webp','.jpg','.jpeg','.gif','.mp4','.webm']:
  possibilities=[ROOT/value,parent/value]
  for p in possibilities:
   p=p.resolve()
   if not p.is_relative_to(ROOT):continue
   name=p.relative_to(ROOT).as_posix()
   # Review-set PNGs are generated copies, not the source frames consumed by
   # the historic validators. Keep original inputs, remove replaced copies.
   if name in receipts and '/review-set/' not in name:
    references.setdefault(name,set()).add(origin)
for p in (ROOT/'docs').rglob('*.json'):
 if p.is_relative_to(OUT):continue
 try:walk(json.loads(p.read_text(encoding='utf8')),p.parent,p.relative_to(ROOT).as_posix())
 except (ValueError,UnicodeError):continue
shutil.copy2(OUT/'cleanup.json',AUDIT/'initial-cleanup.json')
revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()
git=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
restored=[]
try:
 for name in sorted(references):
  p=(ROOT/name).resolve();assert p.is_relative_to(ROOT) and name not in protected and not p.exists(),name
  git.stdin.write((revision+':'+name+'\n').encode('utf8'));git.stdin.flush()
  header=git.stdout.readline().split();assert len(header)==3 and header[1]==b'blob',name
  size=int(header[2]);chunks=[];remaining=size
  while remaining:
   block=git.stdout.read(remaining);assert block;chunks.append(block);remaining-=len(block)
  data=b''.join(chunks);assert git.stdout.read(1)==b'\n'
  assert hashlib.sha256(data).hexdigest()==receipts[name]['sha256'] and len(data)==receipts[name]['bytes'],name
  p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
  restored.append({'path':name,'bytes':size,'reason':'Historical verifier dynamically resolves the original frame through its retained JSON manifest.','manifests':sorted(references[name])})
finally:
 git.stdin.close();git.wait()
report['deleted']=[e for n,e in receipts.items() if n not in references]
report['deleted_files']=len(report['deleted']);report['released_bytes']=sum(e['bytes'] for e in report['deleted'])
report['retained_dynamic_inputs']=restored
report['retained_static_inputs_count']=len(report['retained_script_inputs'])
report['retained_dynamic_inputs_count']=len(restored)
report['retention_base_commit']=revision
report['preserved']='All Markdown, store screenshots, pre-existing drafts, explicit script inputs and original frames resolved dynamically from retained historic manifests. Replaced review copies and unreferenced evidence remain deleted.'
assert all(not (ROOT/e['path']).exists() for e in report['deleted'])
for name,digest in protected.items():assert (ROOT/name).is_file() and hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
(OUT/'cleanup.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'deleted_files':report['deleted_files'],'released_bytes':report['released_bytes'],'restored_dynamic_inputs':len(restored)}))
