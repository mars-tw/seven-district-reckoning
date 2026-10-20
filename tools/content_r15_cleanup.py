"""Plan and remove only unchanged tracked superseded media; preserve verifier inputs."""
import argparse, hashlib, json, re, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
AUDIT=ROOT/'.audit-tmp/content-r15'
OUT=ROOT/'docs/content/r15'
MEDIA={'.png','.jpg','.jpeg','.webp','.gif','.mp4','.webm'}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf8')
def main():
 p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');args=p.parse_args()
 assert Path.cwd().resolve()==ROOT.resolve()
 protected=json.loads((AUDIT/'ownership.json').read_text(encoding='utf8'))['protected']
 tracked=set(filter(None,git('ls-files','-z').split('\0')))
 dirty=set(filter(None,git('diff','--name-only','-z').split('\0')))
 candidates={n for n in tracked if (ROOT/n).is_file() and Path(n).suffix.lower() in MEDIA
  and re.match(r'docs/(?:content/r(?:[1-9]|1[0-4])/|evidence/|art/compare/)',n)
  and n not in protected and n not in dirty}
 references={}
 def visit(v,base,origin):
  if isinstance(v,dict):
   for child in v.values(): visit(child,base,origin)
  elif isinstance(v,list):
   for child in v: visit(child,base,origin)
  elif isinstance(v,str) and Path(v).suffix.lower() in MEDIA:
   for path in [ROOT/v,base/v]:
    path=path.resolve()
    if path.is_relative_to(ROOT):
     n=path.relative_to(ROOT).as_posix()
     if n in candidates: references.setdefault(n,set()).add(origin)
 # Historic manifests dynamically locate the original input frames. Replaced
 # review-set files are copies, not the source PNGs consumed by validators.
 for manifest in (ROOT/'docs').rglob('*.json'):
  if manifest.name in ['cleanup.json','review-set.json'] or manifest.is_relative_to(OUT): continue
  try: visit(json.loads(manifest.read_text(encoding='utf8')),manifest.parent,manifest.relative_to(ROOT).as_posix())
  except (ValueError,UnicodeError): pass
 scripts='\n'.join(p.read_text(encoding='utf8') for directory in ['tools','tests'] for p in (ROOT/directory).rglob('*') if p.suffix in ['.py','.mjs','.gd'])
 keep=[];delete=[]
 for n in sorted(candidates):
  path=ROOT/n
  direct=n in scripts or (path.name in scripts and '/review-set/' not in n)
  origins=sorted(references.get(n,[]))
  if direct or origins and '/review-set/' not in n:
   keep.append({'path':n,'reason':'Verifier source input: explicit script reference or dynamically resolved historical manifest.','manifests':origins})
  else: delete.append({'path':n,'bytes':path.stat().st_size,'sha256':sha(path)})
 plan={'status':'PREPARED','delete':delete,'retained_script_inputs':keep,'protected_files':len(protected),'scope':'Tracked unchanged superseded content/evidence media only. All store screenshots, Markdown and pre-existing untracked files preserved.'}
 OUT.mkdir(parents=True,exist_ok=True)
 (AUDIT/'cleanup-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 if args.apply:
  # Verify every resolved path, identity and owner receipt before any deletion.
  for e in delete:
   path=(ROOT/e['path']).resolve()
   assert path.is_relative_to(ROOT) and e['path'] in tracked and e['path'] not in dirty and e['path'] not in protected
   assert path.is_file() and path.stat().st_size==e['bytes'] and sha(path)==e['sha256']
  for n,h in protected.items(): assert (ROOT/n).is_file() and sha(ROOT/n)==h,n
  for e in delete: (ROOT/e['path']).unlink()
  assert all(not (ROOT/e['path']).exists() for e in delete)
  plan.update(status='EXECUTED',deleted_files=len(delete),released_bytes=sum(e['bytes'] for e in delete),post_cleanup_tests='PREPARED: complete suite rerun required')
  (OUT/'cleanup.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
 print(json.dumps({'status':plan['status'],'files':len(delete),'bytes':sum(e['bytes'] for e in delete),'retained':len(keep)}))
if __name__=='__main__': main()
