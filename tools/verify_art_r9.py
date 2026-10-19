"""Verify the concrete round-six delivery and the explicit Git index."""
import hashlib,json,re,subprocess
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/evidence/r9-art'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))
def encloses(a,b):return b[0]>=a[0]-.5 and b[1]>=a[1]-.5 and b[0]+b[2]<=a[0]+a[2]+.5 and b[1]+b[3]<=a[1]+a[3]+.5
def main():
 base=read('docs/evidence/r9-art/baseline.json');protected=base['protected']
 changed=[p for p,h in protected.items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h]
 assert not changed,changed
 art=read('assets/art/r9/manifest.json');assert art['generated_masters']==1 and art['runtime_images']==2
 for row in art['outputs']:
  assert sha(ROOT/row['path'])==row['sha256'] and row['character_gate']['pass']
  assert list(Image.open(ROOT/row['path']).size)==row['size']
  assert sha(ROOT/row['source'])==row['source_sha256']
 model=read('assets/art/r9/models.json');validation=read('docs/evidence/r9-art/model-validation.json')
 assert validation['status']=='VERIFIED' and all(validation['checks'].values())
 for row in model['outputs']:
  assert sha(ROOT/row['path'])==row['sha256'] and sha(ROOT/row['source'])==row['source_sha256']
  if row['id']!='mei-workbench':assert len(row['animation_names'])==8
 m=read('docs/art/compare/r9-after/manifest.json');budget=read('docs/evidence/r9-art/export-budget.json')
 assert m['status']=='VERIFIED' and not m['failures'] and len(m['views'])==10
 assert m['pck_sha256']==budget['pck_sha256']==sha(ROOT/'deliverables/web/game.pck')
 geometric=0;subject={};stores=[]
 for view in m['views']:
  pixels=(view['pixels']['width'],view['pixels']['height']);screen=view['viewport']
  assert 'NVIDIA' in view['game_renderer'] and not view['logs'] and not view['blocked_remote_origins']
  assert len(view['shots'])==7 and len(view['inspections'])==2 and len(view['reopen_checks'])==3
  assert view['last_layout']['peak_sorts_per_frame']<=32
  rows=view['shots']+view['inspections']+view.get('street_angles',[])+view.get('clock_seal',[])+view.get('seal_screencast',[])+view.get('seal_animation',[])
  for row in rows:
   p=ROOT/'docs/art/compare/r9-after'/row['file']
   assert sha(p)==row['sha256'] and Image.open(p).size==pixels
  for row in view['inspections']:
   d=row['state']['art']['details']['inspection'];circles=[x for x in d['marks'] if x['circled']]
   assert len(circles)==(1 if d['receipt'] else 0)
   assert not circles or circles[0]['text']=='林○翔（個人）'
   assert d['paper'][1]*2/screen['height']<=.10
   assert not (d['close'][1]<d['paper'][1]+d['paper'][3]-.5)
   for label in d['labels']:assert encloses(d['paper'],label['rect']),(row['file'],label);geometric+=1
  if pixels[0] in [1290,2064]:
   for row in view['shots']+view['inspections']:
    assert sha(ROOT/'docs/store/screenshots'/row['file'])==row['sha256'];stores.append(row['file'])
    if row['file'].endswith(('-evidence.png','-link.png','-sealed.png')):
     paper=row['state']['layout']['panel']
     for label in row['state']['art']['details']['case_labels']:
      assert encloses(paper,label['rect']) and label['rect'][0]>=paper[0]+40,(row['file'],label);geometric+=1
   frames=view['clock_seal'];assert len(frames)==3 and len({x['sha256'] for x in frames})==3
   assert frames[2]['state']['art']['details']['seal']['applicator']
   action=f'{pixels[0]}x{pixels[1]}-seal-action.png'
   assert sha(ROOT/'docs/store/screenshots'/action)==frames[2]['sha256'];stores.append(action)
  if pixels==(390,844):
   street=next(x['state'] for x in view['shots'] if x['file'].endswith('-street.png'))
   subject={k:street['art'][k] for k in ['hero_height_px','mei_height_px']};assert min(subject.values())>=40
 tests=read('docs/evidence/r9-art/final-source-tests.json')
 assert len(tests)==30 and all(t['status']=='PASS' and t['reported_failures']==0 for t in tests)
 assert all(t['source_fingerprint']['digest']==budget['source_fingerprint']['digest'] for t in tests)
 staged=[p for p in subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode().split('\0') if p]
 assert not (set(staged)&(set(protected)-{'tools/prepare_art_r9.py','docs/OPTIM_PLAN_R9.md'})), 'Owner files entered the index'
 patterns=[re.compile(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}'),re.compile(r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'),re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')]
 findings=[];scanned=0;runtime_mismatches=[]
 for item in subprocess.check_output(['git','ls-files','--stage','-z'],cwd=ROOT).decode().split('\0'):
  if not item:continue
  _,oid,tail=item.split(' ',2);_,name=tail.split('\t',1)
  if Path(name).suffix.lower() not in ['.gd','.gdshader','.py','.mjs','.js','.json','.md','.html','.cfg','.yml','.txt','.godot','.import','.uid','.css']:continue
  content=subprocess.check_output(['git','cat-file','blob',oid],cwd=ROOT).decode('utf8',errors='replace');scanned+=1
  if any(p.search(content) for p in patterns):findings.append(name)
 assert not findings,findings
 for name in staged:
  if not name.startswith(('godot/','web/','tests/')):continue
  p=ROOT/'.audit-tmp/r9-export'/name;actual=p.read_bytes() if p.is_file() else b''
  expected=subprocess.check_output(['git','show',':'+name],cwd=ROOT)
  if Path(name).suffix.lower() in ['.gd','.gdshader','.json','.html','.cfg','.godot','.import','.uid','.mjs','.css']:
   actual=actual.replace(b'\r\n',b'\n');expected=expected.replace(b'\r\n',b'\n')
  if actual!=expected:runtime_mismatches.append(name)
 assert not runtime_mismatches,runtime_mismatches
 result=dict(status='VERIFIED',version='0.13.0',store_screenshots=len(stores),geometry_checks=geometric,subject_height_css_px=subject,tests={'suites':len(tests)-1,'checks':sum(t['reported_checks'] for t in tests),'failures':0},protected_files_unchanged=len(protected),staged_paths=len(staged),secret_scan={'indexed_text_files':scanned,'findings':[]},runtime_index_matches_export=True,pck_sha256=m['pck_sha256'],release_status='BLOCKED',limitations=['Independent 8/10 rescore outstanding','Desktop concurrent-load p95 and clean native/device GPU validation outstanding','3D runtime per-object color masks not verified'])
 (OUT/'artifact-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
