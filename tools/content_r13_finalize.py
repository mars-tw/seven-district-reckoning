"""Verify current captures, local ownership, cleanup and explicit staging."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
from PIL import Image
from scan_publication import scan_text

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r13'
AUDIT=ROOT/'.audit-tmp/content-r13'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf8'))
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def finalize(captures,stage):
 assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).decode().strip()=='main','Unexpected task branch'
 protected=read(AUDIT/'ownership.json')['protected']
 for n,h in protected.items():assert (ROOT/n).is_file() and sha(ROOT/n)==h,n
 tests=read(OUT/'tests.json');assert len(tests)==44 and all(t['status']=='PASS' for t in tests), 'Full post-cleanup test run must pass'
 export=read(OUT/'export.json')
 assert all(t['source_fingerprint']['digest']==export['source_fingerprint']['digest'] for t in tests),'Source fingerprints differ'
 views={};reports=[]
 for p in captures:
  p=ROOT/p;data=read(p);assert data['pck_sha256']==export['pck_sha256'],'Stale capture PCK'
  reports.append({'file':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
  for v in data['views']:
   if v.get('status')!='VERIFIED':continue
   assert v['tag'] not in views,'Duplicate verified viewport'
   views[v['tag']]=(v,p.parent)
 assert set(views)=={'390x844','320x568','1290x2796','2064x2752','844x390','1024x768'},'Six final viewports required'
 images={};acceptance=[]
 for tag,(v,directory) in views.items():
  canonical={s['file']:s for s in v['shots']}
  for filename,s in canonical.items():
   source=directory/filename;assert sha(source)==s['sha256'],filename
   with Image.open(source) as im:assert im.size==tuple(map(int,tag.split('x'))),(filename,im.size)
   target=OUT/filename
   if source.resolve()!=target.resolve():shutil.copy2(source,target)
   images[filename]={'file':target.relative_to(ROOT).as_posix(),'sha256':sha(target),'size':list(map(int,tag.split('x')))}
   ui=s['state']['investigations']['ui']
   if ui.get('visible') and tag in ['390x844','320x568']:
    w,h=map(int,tag.split('x'));x,y,pw,ph=ui['paper_rect']
    assert h-y-ph<=h*.05 and y>=0 and y+ph<=h+.5,'Exterior paper gap'
    for ink in ui['labels']+ui['buttons']:
     assert not any(line.startswith('｜') for line in ink['rendered_text'].split('\n')),'Leading divider'
    acceptance.append({'file':filename,'bottom_nonpaper_px':h-y-ph,'paper_y':y})
  assert v['checks'][-1].get('indexeddb_cold_reload')=='VERIFIED','Cold reload not complete'
 for p in OUT.glob('*.png'):
  if p.name not in images:
   assert p.relative_to(ROOT).as_posix() not in protected
   p.unlink() # Only this task's unreferenced interim R13 PNGs.
 load_reports=[]
 for capture in captures:
  p=(ROOT/capture).parent/'host-load.json'
  if p.exists():load_reports.append({'capture':capture,'sha256':sha(p),'measurement':read(p)})
 write(OUT/'host-load.json',{'status':'EXECUTED','runs':load_reports,'scope':'Concurrent host load only; owner GPU workloads were preserved.'})
 def shot(tag,name):
  v,_=views[tag];return next(s for s in reversed(v['shots']) if s['file']==('phone-'+name+('' if tag=='390x844' else '-'+tag)+'.png'))
 for tag in ['390x844','320x568']:
  for case in ['second_help','before_night','three_voices']:
   archived=shot(tag,case+'-sealed')['state']['investigations']['progress']['records'][case]
   for page in ['sealed-reloaded','chain-reloaded','history-reloaded']:
    assert shot(tag,case+'-'+page)['state']['investigations']['progress']['records'][case]==archived,'Exact archive/history reload'
  for index in range(3):
   for step in [1,2,3]:assert shot(tag,f'before_night-reveal-{index}-{step}')['state']['investigations']['ui']['reveal_steps'][index]==step
  first=shot(tag,'second_help-action-payment-retry')['state']['investigations']
  assert len([e for e in first['progress']['records']['second_help']['history'] if e['feedback']])==1
  assert not any('最新補充未撤回甲，付款仍有矛盾' in l['text'] for l in first['ui']['labels'])
  for case in ['second_help','before_night','three_voices']:
   street=shot(tag,case+'-street-'+('actual' if case=='second_help' else 'result'))['state']['investigations']
   assert not any(t in street['field']['objective'] for t in ['體力','已讀取','公尺'])
   action=[a for a in street['field']['actions'] if a['action']=='interact']
   if tag=='390x844':assert len(action)==1 and action[0]['text']=='互動'
   else:assert not action, '320 held layout expected to expose its known street-control block'
 # Pixel evidence checks the title ink itself, not only Control coordinates.
 pixel_headers={}
 for tag in ['390x844','320x568']:
  v,_=views[tag]
  for case,rows in v.get('dossier_headers',{}).items():
   reference=None;records=[]
   for row in rows:
    s=shot(tag,row['name']);title=next(l for l in s['state']['investigations']['ui']['labels'] if l['text']=={'second_help':'第二次求助，第二次收費','before_night':'晚班之前的收據','three_voices':'三張嘴，一句真話'}[case])
    x,y,w,h=map(round,title['rect'])
    with Image.open(OUT/s['file']) as im:
     pixels=im.crop((x,y,x+w,y+h)).convert('RGB').tobytes()
     ink=bytes(int(max(pixels[i:i+3])<90) for i in range(0,len(pixels),3))
    if reference is None:reference=(title['rect'],ink)
    assert title['rect'][1]==reference[0][1] and ink==reference[1],(tag,case,'Title pixels changed')
    records.append({'file':s['file'],'title_y':y,'ink_sha256':hashlib.sha256(ink).hexdigest()})
   pixel_headers[tag+'-'+case]=records
 selection=['second_help-paper-b-marked','second_help-action-payment-retry','second_help-full-original-after-error','second_help-sealed','second_help-street-actual','before_night-reveal-0-1','before_night-reveal-0-2','before_night-reveal-0-3','before_night-attachment-picked','before_night-street-result','three_voices-support-one-side','three_voices-wrong-pin-with-two-preserved','three_voices-local-pin-repaired','three_voices-chain-reloaded','three_voices-street-result']
 review=OUT/'review-set';review.mkdir(exist_ok=True);selected=[]
 for i,n in enumerate(selection,1):
  p=OUT/f'phone-{n}.png';target=review/f'{i:02d}-{n}.png';shutil.copy2(p,target);assert sha(p)==sha(target)
  selected.append({'file':target.relative_to(ROOT).as_posix(),'original':p.relative_to(ROOT).as_posix(),'sha256':sha(target)})
 assert len(list(review.glob('*.png')))==15
 store=[]
 for tag in ['1290x2796','2064x2752']:
  original=OUT/(('phone-' if tag=='1290x2796' else tag+'-')+'before_night-attachment-picked'+('-'+tag if tag=='1290x2796' else '')+'.png')
  target=ROOT/'docs/store/screenshots'/f'{tag}-content-r13-before_night-attachment-picked.png';shutil.copy2(original,target);assert sha(original)==sha(target);store.append(target.relative_to(ROOT).as_posix())
 write(ROOT/'docs/store/screenshots/CONTENT_R13_STATUS.json',{'status':'VERIFIED','version':'0.27.0','new_screenshots':store,'existing_screenshots_deleted':False})
 write(OUT/'review-set.json',{'status':'VERIFIED','images':selected,'case_counts':[5,5,5],'resized_or_composited':False})
 write(OUT/'acceptance.json',{'status':'VERIFIED','paper_exterior':acceptance,'title_pixel_alignment':pixel_headers,'manual_cover_steps':[1,2,3],'reference_images':images,'capture_reports':reports,'scope':'UI bounds plus exact title ink, real touch mechanics, whole archive/history after cold reload; physical devices and external Muse score not claimed'})
 merged=read(ROOT/captures[0]);merged.update(status='VERIFIED',views=[views[t][0] for t in views],failures=[],source_capture_reports=reports)
 merged['run_mode']='direct-case-flow'
 merged['method']='Actual unedited native-size Godot Web PNGs in headless hardware Chromium. Native headless-world unfinished ready saves supply the collected sources; visible touch performs marking, retries, complete-source reopening, manual covers, attachment, judgments, local pin repair and sealing. All six viewports cold-reload exact archived records. Browser street travel/collection is not claimed; native suites separately test actual field collection and exhaustive timeline drag previews/cancel.'
 merged['guards']=[g for g in merged['guards'] if g not in ['drag_preview_matches_drop','drag_cancel_preserves_order']]
 merged['guard_scope']='Browser bounds, touch44, text, manual cover state, archive equality and remote-request guards; drag permutations/cancel belong to the independent native suites, not this direct browser flow.'
 write(OUT/'manifest.json',merged)
 cleanup=read(OUT/'cleanup.json');cleanup['post_cleanup_tests']='VERIFIED: complete test_game.py run, all suites PASS';write(OUT/'cleanup.json',cleanup)
 write(OUT/'ownership-check.json',{'status':'VERIFIED','protected_files':len(protected),'changed':[]})
 result={'status':'VERIFIED','version':'0.27.0','suites':len(tests)-1,'reported_checks':sum(t['reported_checks'] for t in tests),'failures':0,'web_views':len(views),'native_size_images':len(images),'review_images':15,'store_images':len(store),'new_generated_assets':1,'cleanup_deleted':cleanup['deleted_files'],'released_bytes':cleanup['released_bytes'],'protected_files_unchanged':len(protected),'source_fingerprint':export['source_fingerprint'],'pck_sha256':export['pck_sha256'],'concurrent_performance':views['390x844'][0].get('performance',{}),'external_acceptance':'BLOCKED: actual Muse rescore, physical devices, human play and clean-host native timings require external conditions.'};write(OUT/'verification.json',result)
 result['small_phone_street']='BLOCKED: 320x568 held touch layout has no visible interact action; complete dossier touch mechanics and saved results are verified. The user-protected touch_controls.gd was not modified.'
 write(OUT/'verification.json',result)
 report=ROOT/'docs/CODEX_RESPONSE_CONTENT_R13.md'
 assert len(result['concurrent_performance'].get('runs',[]))==3,'Three reference timing runs required'
 body=report.read_text(encoding='utf8')
 for key,value in {'STATUS':'VERIFIED','SUITES':result['suites'],'CHECKS':result['reported_checks'],'PROTECTED':len(protected),'DELETED':cleanup['deleted_files'],'BYTES':f"{cleanup['released_bytes']:,}",'MIB':round(cleanup['released_bytes']/1048576,2),'STATIC':len(cleanup['retained_script_inputs']),'DYNAMIC':len(cleanup.get('retained_dynamic_inputs',[])),'P95':round(result['concurrent_performance'].get('p95_median',0),2)}.items():body=body.replace('{{'+key+'}}',str(value))
 body=re.sub(r'最終 \d+ 套、[\d,]+ 項檢查',f"最終 {result['suites']} 套、{result['reported_checks']:,} 項檢查",body)
 body=re.sub(r'三跑 RAF p95 中位 [\d.]+ms',f"三跑 RAF p95 中位 {round(result['concurrent_performance']['p95_median'],2)}ms",body)
 assert '{{' not in body
 report.write_text(body,encoding='utf8')
 for name in ['README.md','godot/project.godot','web/shell.html','docs/store/LISTING_ZH_TW.md']:
  text=(ROOT/name).read_text(encoding='utf8');assert '0.27.0' in text and '0.26.0' not in text
 # Explicit current task paths only; pre-existing owner drafts never enter index.
 changed=subprocess.check_output(['git','diff','--name-only','-z'],cwd=ROOT,stderr=subprocess.PIPE).decode('utf8').split('\0')
 own=[n for n in changed if n and n not in protected]
 own+=['docs/OPTIM_PLAN_CONTENT_R13.md','docs/CODEX_RESPONSE_CONTENT_R13.md','tests/content_r13.gd']
 own += [p.relative_to(ROOT).as_posix() for folder in ['tools','docs/content/r13','godot/assets/art/content-r13','assets/art/content-r13'] for p in (ROOT/folder).rglob('*') if p.is_file() and (folder!='tools' or p.parent==ROOT/'tools' and p.name.startswith('content_r13_') and p.suffix in ['.py','.mjs'])]
 own += store+['docs/store/screenshots/CONTENT_R13_STATUS.json']
 own=sorted(set(own));assert not set(own)&set(protected)
 assert all((ROOT/n).is_file() or n in {e['path'] for e in cleanup['deleted']} for n in own)
 findings=[]
 tracked=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0')
 for name in sorted(set(tracked+own)):
  if not name or not (ROOT/name).is_file():continue
  p=ROOT/name
  if p.suffix.lower() in ['.png','.webp','.glb','.blend','.wav','.otf','.zip']:continue
  try:data=(subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT) if name in protected and name in tracked else p.read_bytes()).decode('utf8')
  except UnicodeError:continue
  findings+=scan_text(p,data)
 write(OUT/'secrets-scan.json',{'status':'VERIFIED' if not findings else 'BLOCKED','findings':findings});assert not findings,findings[:3]
 own.append('docs/content/r13/secrets-scan.json');own=sorted(set(own));write(AUDIT/'owned-files.json',own)
 if stage:
  assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=ROOT).strip(),'Index contains another change'
  for i in range(0,len(own),10):subprocess.run(['git','add','--',*own[i:i+10]],cwd=ROOT,check=True,capture_output=True)
  staged=set(filter(None,subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0')))
  assert staged<=set(own) and not staged&set(protected)
 print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--capture',action='append',required=True);p.add_argument('--stage',action='store_true');a=p.parse_args();finalize(a.capture,a.stage)
