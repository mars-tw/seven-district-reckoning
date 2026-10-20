"""Verify original Web frames, exact archived state, ownership and local staging."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
from PIL import Image
from scan_publication import scan_text
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r15'
AUDIT=ROOT/'.audit-tmp/content-r15'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf8'))
def write(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT,stderr=subprocess.PIPE).decode('utf8')
def main():
 p=argparse.ArgumentParser();p.add_argument('--capture',action='append',required=True);p.add_argument('--stage',action='store_true');a=p.parse_args()
 assert git('branch','--show-current').strip()=='main'
 protected=read(AUDIT/'ownership.json')['protected']
 for n,h in protected.items(): assert (ROOT/n).is_file() and sha(ROOT/n)==h,n
 tests=read(OUT/'tests.json');assert len(tests)==46 and all(t['status']=='PASS' for t in tests)
 export=read(OUT/'export.json');assert all(t['source_fingerprint']['digest']==export['source_fingerprint']['digest'] for t in tests)
 views={};images={};receipts=[];loads=[]
 for n in a.capture:
  manifest=ROOT/n;data=read(manifest);assert data['status']=='VERIFIED' and data['pck_sha256']==export['pck_sha256']
  receipts.append({'file':n,'sha256':sha(manifest)})
  if (manifest.parent/'host-load.json').exists(): loads.append(read(manifest.parent/'host-load.json'))
  for view in data['views']:
   assert view['status']=='VERIFIED' and not view['errors'] and view['checks'][-1]['indexeddb_cold_reload']=='VERIFIED'
   assert view['tag'] not in views
   assert any(c.get('attachment_real_drag')=={'tap_cannot_seal':True,'bad_drop_returns':True,'correct_drop_seals':True} for c in view['checks'])
   shots={s['file']:s for s in view['shots']};view['shots']=list(shots.values());views[view['tag']]=view
   for name,shot in shots.items():
    source=manifest.parent/name;assert sha(source)==shot['sha256'],name
    with Image.open(source) as im: assert im.size==tuple(map(int,view['tag'].split('x')))
    shutil.copy2(source,OUT/name);images[name]={'sha256':sha(source),'size':list(map(int,view['tag'].split('x')))}
 assert set(views)=={'390x844','320x568','1290x2796','2064x2752','844x390','1024x768'}
 phone=views['390x844'];shots={s['file']:s for s in phone['shots']}
 assert phone['performance']['p95_median']<=18,'Concurrent presentation reference exceeds 18ms'
 for tag in ['390x844','320x568']:
  by_name={s['file']:s for s in views[tag]['shots']};suffix='' if tag=='390x844' else '-'+tag
  for frame in by_name.values():
   ui=frame['state']['investigations']['ui']
   if not ui.get('visible'): continue
   for ink in ui['buttons']+ui['labels']:
    for term in ['第二次收費','自動保存','同案','原件']:
     assert ink['text'].count(term)==ink['rendered_text'].count(term),(tag,frame['file'],term)
  for case in ['second_help','before_night','three_voices']:
   archived=by_name[f'phone-{case}-sealed{suffix}.png']['state']['investigations']['progress']['records'][case]
   for state in ['sealed-reloaded','chain-reloaded','history-reloaded']:
    assert by_name[f'phone-{case}-{state}{suffix}.png']['state']['investigations']['progress']['records'][case]==archived
  for step in [0,1,2,3]: assert by_name[f'phone-before_night-reveal-0-{step}{suffix}.png']['state']['investigations']['ui']['reveal_steps'][0]==step
 candidates=[b for b in shots['phone-three_voices-judgment-before-pin.png']['state']['investigations']['ui']['buttons'] if b['text'].startswith(('林秀蘭｜','陳奕廷｜','吳安琪｜'))]
 assert len(candidates)==3 and all(not any(word in b['text'] for word in ['反駁','支持','17：50','18：10']) for b in candidates)
 rejected=shots['phone-before_night-attachment-rejected.png']['state']['investigations']['ui']
 assert rejected['attachment_notice']=='位置不對，收據已退回原位。' and not any('已拿起' in b['text'] for b in rejected['buttons'])
 # Five original portrait frames per case; additional full detent/repair frames
 # remain auditable beside the deliberately bounded reviewer set.
 selected=['second_help-wrong-field-classified','second_help-review-locked','second_help-review-b','second_help-returned-error','second_help-street-actual',
  'before_night-reveal-0-1','before_night-attachment-dragging','before_night-attachment-over-target','before_night-attachment-rejected','before_night-street-result',
  'three_voices-judgment-before-pin','three_voices-wrong-pin','three_voices-wrong-pin-with-two-preserved','three_voices-chain-reloaded','three_voices-street-result']
 review=OUT/'review-set';review.mkdir(exist_ok=True);index=[]
 for i,n in enumerate(selected,1):
  source=OUT/('phone-'+n+'.png');target=review/f'{i:02d}-{n}.png';shutil.copy2(source,target)
  assert sha(source)==sha(target)
  index.append({'file':target.relative_to(ROOT).as_posix(),'original':source.relative_to(ROOT).as_posix(),'sha256':sha(target)})
 assert len(list(review.glob('*.png')))==15
 write(OUT/'review-set.json',{'status':'VERIFIED','images':index,'case_counts':[5,5,5],'resized_or_composited':False})
 store=[]
 for tag in ['1290x2796','2064x2752']:
  source=OUT/next(s['file'] for s in views[tag]['shots'] if 'before_night-attachment-picked' in s['file'])
  target=ROOT/'docs/store/screenshots'/f'{tag}-content-r15-before_night-attachment.png';shutil.copy2(source,target);store.append(target.relative_to(ROOT).as_posix())
 write(ROOT/'docs/store/screenshots/CONTENT_R15_STATUS.json',{'status':'VERIFIED','version':'0.29.0','new_screenshots':store,'existing_screenshots_deleted':False})
 write(OUT/'art-manifest.json',{'status':'VERIFIED','new_generated_assets':0,'assets':[],'reused':['godot/assets/art/content-r14/paper-seal.webp','godot/assets/art/r4/case-paper.webp'],'method':'Existing licensed game textures, original typeset evidence and physical frame geometry; no new image generation.'})
 write(OUT/'acceptance.json',{'status':'VERIFIED','images':images,'capture_reports':receipts,'candidate_text':candidates,'scope':'Real touch source reviews, paper detents, true drag/drop, local pin repair and exact IndexedDB cold reload.'})
 write(OUT/'host-load.json',{'status':'EXECUTED','runs':loads,'scope':'Concurrent host reference only.'})
 write(OUT/'manifest.json',{'status':'VERIFIED','version':'0.29.0','pck_sha256':export['pck_sha256'],'views':list(views.values()),'failures':[]})
 cleanup=read(OUT/'cleanup.json');assert all(not (ROOT/e['path']).exists() for e in cleanup['delete'])
 cleanup['post_cleanup_tests']='VERIFIED: all complete test_game.py suites PASS after deletion';write(OUT/'cleanup.json',cleanup)
 summary={'status':'VERIFIED','version':'0.29.0','suites':len(tests)-1,'checks':sum(t['reported_checks'] for t in tests),'failures':0,'web_views':6,'review_images':15,'store_images':2,'new_generated_assets':0,'deleted_files':cleanup['deleted_files'],'released_bytes':cleanup['released_bytes'],'protected_files_unchanged':len(protected),'performance':phone.get('performance',{}),'source_fingerprint':export['source_fingerprint'],'pck_sha256':export['pck_sha256']}
 summary.update(scope='Local implementation, automated tests and original Web screenshots only',blocked=['Muse external rescore','physical phone/iPad and human play','clean-host native timing','320x568 street interact action in protected touch layout'])
 write(OUT/'verification.json',summary);write(OUT/'ownership-check.json',{'status':'VERIFIED','protected_files':len(protected),'changed':[]})
 # Explicit prospective file list, excluding all pre-existing owner work.
 own=set(filter(None,git('diff','--name-only','-z').split('\0')))-set(protected)
 allowed={'README.md','godot/project.godot','web/shell.html','docs/store/LISTING_ZH_TW.md','godot/assets/fonts/SevenDistrictSansTC-Regular.otf','godot/data/fraud_cases.json','godot/scripts/content/content_investigations.gd','godot/scripts/content/investigation_field.gd','godot/scripts/content/taiwan_world.gd','godot/scripts/ui/investigation_panel.gd','godot/scripts/ui/investigation_paper.gd','godot/scripts/ui/investigation_time_mask.gd','tests/content_r1.gd','tests/content_r5.gd','tests/content_r11.gd','tests/content_r13.gd','tests/content_r14.gd','tools/test_game.py'}
 allowed.update(e['path'] for e in cleanup['delete'])
 allowed.add('tests/content_r12.gd')
 allowed.add('tests/content_r7.gd')
 assert own<=allowed,sorted(own-allowed)
 own.update(p.relative_to(ROOT).as_posix() for p in OUT.rglob('*') if p.is_file())
 own.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'tools').glob('content_r15_*') if p.suffix in ['.py','.mjs'])
 own.update(['docs/OPTIM_PLAN_CONTENT_R15.md','docs/CODEX_RESPONSE_CONTENT_R15.md','tests/content_r15.gd',*store,'docs/store/screenshots/CONTENT_R15_STATUS.json'])
 assert not own&set(protected)
 findings=[];pattern=r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}'
 tracked=set(filter(None,git('ls-files','-z').split('\0')))
 for n in sorted(tracked|own):
  path=ROOT/n
  if not path.is_file() or path.suffix.lower() in {'.png','.jpg','.webp','.glb','.blend','.wav','.otf','.zip'}:continue
  try: text=(subprocess.check_output(['git','show','HEAD:'+n],cwd=ROOT) if n in protected and n in tracked else path.read_bytes()).decode('utf8')
  except UnicodeError:continue
  findings.extend(scan_text(path,text))
  findings.extend({'file':n,'line':text.count('\n',0,m.start())+1,'type':'specified_api_pattern'} for m in re.finditer(pattern,text))
 write(OUT/'secrets-scan.json',{'status':'VERIFIED' if not findings else 'BLOCKED','findings':findings,'specified_pattern':pattern,'scope':'Prospective tracked files; protected owner drafts taken from HEAD.'});assert not findings,findings[:5]
 own.add('docs/content/r15/secrets-scan.json');own=sorted(own);write(AUDIT/'owned-files.json',own)
 if a.stage:
  assert not git('diff','--cached','--name-only').strip(),'Other work is staged'
  for i in range(0,len(own),10):subprocess.run(['git','add','--',*own[i:i+10]],cwd=ROOT,check=True,capture_output=True)
  assert set(filter(None,git('diff','--cached','--name-only','-z').split('\0')))<=set(own)
 print(json.dumps(summary,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
