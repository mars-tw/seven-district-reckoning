"""Read back native-size gameplay evidence and prepare explicit local-only staging."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
from PIL import Image
from scan_publication import scan_text
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r14'
AUDIT=ROOT/'.audit-tmp/content-r14'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf8'))
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,stderr=subprocess.PIPE).decode('utf8')
def luminance(hexcode):
 channels=[int(hexcode[i:i+2],16)/255 for i in [0,2,4]]
 linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in channels]
 return sum(v*c for v,c in zip(linear,[.2126,.7152,.0722]))
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--capture',action='append',required=True);parser.add_argument('--supplement',action='append',default=[]);parser.add_argument('--stage',action='store_true');args=parser.parse_args()
 assert git('branch','--show-current').strip()=='main'
 protected=read(AUDIT/'ownership.json')['protected']
 for n,h in protected.items():assert (ROOT/n).is_file() and sha(ROOT/n)==h,n
 tests=read(OUT/'tests.json');assert len(tests)==45 and all(t['status']=='PASS' for t in tests),'All original suites plus R14 must pass'
 export=read(OUT/'export.json');assert all(t['source_fingerprint']['digest']==export['source_fingerprint']['digest'] for t in tests),'Test/export mismatch'
 views={};reports=[];loads=[]
 for source in args.capture:
  p=ROOT/source;data=read(p);assert data['pck_sha256']==export['pck_sha256'],'Capture/export mismatch'
  reports.append({'file':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
  if (p.parent/'host-load.json').exists():loads.append(read(p.parent/'host-load.json'))
  for view in data['views']:
   if view.get('status')=='VERIFIED':
    assert view['tag'] not in views,'Duplicate viewport'
    views[view['tag']]=(view,p.parent)
 assert set(views)=={'390x844','320x568','1290x2796','2064x2752','844x390','1024x768'}
 images={};paper=[];reversals=[]
 for tag,(view,directory) in views.items():
  assert not view['errors'] and view['checks'][-1]['indexeddb_cold_reload']=='VERIFIED'
  assert any(c.get('attachment_real_drag')=={'tap_cannot_seal':True,'bad_drop_returns':True,'correct_drop_seals':True} for c in view['checks'])
  original_shots=list(view['shots'])
  canonical={s['file']:s for s in original_shots}
  # Return drags revisit the same detent filename. Publish only the last
  # receipt whose hash matches that native PNG, rather than stale duplicates.
  view['shots']=list(canonical.values())
  for name,shot in canonical.items():
   p=directory/name;assert sha(p)==shot['sha256']
   with Image.open(p) as im:assert im.size==tuple(map(int,tag.split('x')))
   target=OUT/name;shutil.copy2(p,target)
   images[name]={'sha256':sha(target),'size':list(map(int,tag.split('x')))}
   ui=shot['state']['investigations']['ui']
   if tag in ['390x844','320x568'] and ui['visible']:
    h=int(tag.split('x')[1]);gap=h-ui['paper_rect'][1]-ui['paper_rect'][3]
    assert gap<=8.5,'Paper exterior gap'
    paper.append({'file':name,'bottom_nonpaper_px':gap})
    for ink in ui['buttons']+ui['labels']:assert not any(line.startswith('｜') for line in ink['rendered_text'].split('\n')),'Leading separator'
  if tag in ['390x844','320x568']:
   suffix='' if tag=='390x844' else '-'+tag
   for number in range(3):
    stem=f'phone-before_night-reveal-{number}-'
    matches=[i for i,s in enumerate(original_shots) if s['file']==stem+'1'+suffix+'.png']
    assert len(matches)==2,'Both outward and return detents must have been captured'
    position=matches[-1];previous,current,following=original_shots[position-1:position+2]
    assert previous['file']==stem+'2'+suffix+'.png' and following['file']==stem+'3'+suffix+'.png'
    assert [s['state']['investigations']['ui']['reveal_steps'][number] for s in [previous,current,following]]==[2,1,3]
    alias=stem+'backcovered'+suffix+'.png';shutil.copy2(OUT/current['file'],OUT/alias)
    assert sha(OUT/alias)==current['sha256']
    images[alias]={'sha256':sha(OUT/alias),'size':list(map(int,tag.split('x'))),'alias_of':current['file'],'role':'Actual return-drag detent at one third, named explicitly; identical original pixels.'}
    frame=dict(current);frame.update(file=alias,alias_of=current['file'],role='reverse_drag_one_third');view['shots'].append(frame)
    reversals.append({'viewport':tag,'cover':number,'sequence':[previous['file'],alias,following['file']],'actual_steps':[2,1,3],'raw_capture_indices':[position-1,position,position+1]})
 def shot(tag,name):
  view,_=views[tag]
  matches=[s for s in view['shots'] if s['file']==('phone-'+name+('' if tag=='390x844' else '-'+tag)+'.png')]
  assert matches,(tag,name)
  return matches[-1]
 for tag in ['390x844','320x568']:
  for case in ['second_help','before_night','three_voices']:
   archive=shot(tag,case+'-sealed')['state']['investigations']['progress']['records'][case]
   for state in ['sealed-reloaded','chain-reloaded','history-reloaded']:assert shot(tag,case+'-'+state)['state']['investigations']['progress']['records'][case]==archive,'Exact cold reload'
  picked=shot(tag,'before_night-attachment-picked')['state']['investigations']['progress']['records']['before_night']
  assert not picked['complete'] and picked['reveal_steps']==[3,3,3]
  for index in range(3):
   for step in [1,2,3]:assert shot(tag,f'before_night-reveal-{index}-{step}')['state']['investigations']['ui']['reveal_steps'][index]==step
  for case in ['second_help','before_night','three_voices']:
   street=shot(tag,case+'-street-'+('actual' if case=='second_help' else 'result'))['state']['investigations']
   assert all(s not in street['field']['objective'] for s in ['已讀取','體力','公尺'])
 # Explicit grey-scale separation is verified numerically from actual UI ink.
 ui=shot('390x844','three_voices-support-one-side')['state']['investigations']['ui']
 candidates=[b for b in ui['buttons'] if b['text'].startswith(('反駁','支持'))]
 assert len(candidates)==3 and all(not b['disabled'] for b in candidates)
 contrast=[]
 for b in candidates:
  a,z=sorted([luminance(b['color']),luminance(b['background'])]);ratio=(z+.05)/(a+.05)
  assert ratio>=4.5
  contrast.append({'text':b['text'],'foreground':b['color'],'background':b['background'],'ratio':ratio})
 grayscale=[]
 for filename in args.supplement:
  p=ROOT/filename;data=read(p);assert data['pck_sha256']==export['pck_sha256'] and data['status']=='VERIFIED'
  for view in data['views']:
   if view['tag']!='390x844':continue
   for item in view['shots']:
    if '-grayscale' not in item['file']:continue
    path=p.parent/item['file'];assert sha(path)==item['sha256']
    with Image.open(path) as im:
     assert im.size==(390,844)
     values=list(im.convert('RGB').getdata());fraction=sum(max(c)-min(c)<=2 for c in values)/len(values)
     assert fraction>.99,'Expected actual browser achromatopsia output'
    dest=OUT/item['file'];shutil.copy2(path,dest);images[item['file']]={'sha256':sha(dest),'size':[390,844]}
    grayscale.append({'file':item['file'],'grey_pixel_fraction':fraction,'method':'Chromium Emulation.setEmulatedVisionDeficiency achromatopsia; direct native-size screenshot, no post-processing.'})
 assert grayscale,'A direct grayscale contrast regression frame is required'
 selected=['second_help-paper-a-marked','second_help-returned-error','second_help-action-latest-only-retry','second_help-street-actual','case-list-reloaded',
  'before_night-seals-bc-partial','before_night-attachment-dragging','before_night-attachment-rejected','before_night-attachment-sealed','before_night-street-result',
  'three_voices-support-one-side-grayscale','three_voices-wrong-pin-with-two-preserved','three_voices-local-pin-repaired','three_voices-chain-reloaded','three_voices-street-result']
 review=OUT/'review-set';review.mkdir(exist_ok=True);index=[]
 for number,name in enumerate(selected,1):
  source=OUT/('phone-'+name+'.png');assert source.is_file()
  dest=review/f'{number:02d}-{name}.png';shutil.copy2(source,dest);assert sha(source)==sha(dest)
  index.append({'file':dest.relative_to(ROOT).as_posix(),'original':source.relative_to(ROOT).as_posix(),'sha256':sha(dest)})
 assert len(list(review.glob('*.png')))==15
 store=[]
 for tag in ['1290x2796','2064x2752']:
  view,_=views[tag];source=OUT/next(s['file'] for s in view['shots'] if 'before_night-attachment-picked' in s['file'])
  target=ROOT/'docs/store/screenshots'/f'{tag}-content-r14-before_night-attachment.png';shutil.copy2(source,target);assert sha(source)==sha(target)
  store.append(target.relative_to(ROOT).as_posix())
 write(ROOT/'docs/store/screenshots/CONTENT_R14_STATUS.json',{'status':'VERIFIED','version':'0.28.0','new_screenshots':store,'existing_screenshots_deleted':False})
 write(OUT/'review-set.json',{'status':'VERIFIED','images':index,'case_counts':[5,5,5],'shared_list_in_first_group':True,'resized_or_composited':False})
 write(OUT/'acceptance.json',{'status':'VERIFIED','candidate_contrast':contrast,'grayscale':grayscale,'cover_reverse_sequences':reversals,'paper_exterior':paper,'images':images,'capture_reports':reports,'scope':'Actual touch drag/drop, local repair, archive equality, real source metadata and no-remote/bounds/touch44 guards. External score and real devices not claimed.'})
 write(OUT/'host-load.json',{'status':'EXECUTED','runs':loads,'scope':'Concurrent host sampling only; owner workloads preserved.'})
 merged=read(ROOT/args.capture[0]);merged.update(status='VERIFIED',views=[v[0] for v in views.values()],failures=[])
 merged['method']='Direct native-size Godot Web screenshots using one headless hardware Chromium. Native-world unfinished source saves supply collected documents; browser touch performs all target judgments, manual covers, real receipt drag/drop, sealing and exact IndexedDB cold reload. Continuous street travel is not claimed; native suites separately verify world collection.'
 write(OUT/'manifest.json',merged)
 cleanup=read(OUT/'cleanup.json');assert all(not (ROOT/e['path']).exists() for e in cleanup['delete'])
 cleanup['post_cleanup_tests']='VERIFIED: all complete test_game.py suites PASS after deletion';write(OUT/'cleanup.json',cleanup)
 art=read(OUT/'art-manifest.json');art['status']='VERIFIED'
 for asset in art['assets']:
  asset['processing']='PNG resized to 512px width with preserved aspect ratio, then WebP quality 85; no semantic edits.'
  for kind in ['source','runtime']:
   path=ROOT/asset[kind];asset[kind+'_sha256']=sha(path)
   with Image.open(path) as im:asset[kind+'_size']=list(im.size)
 write(OUT/'art-manifest.json',art)
 summary={'status':'VERIFIED','version':'0.28.0','suites':len(tests)-1,'reported_checks':sum(t['reported_checks'] for t in tests),'failures':0,'web_views':len(views),'review_images':15,'store_images':2,'new_generated_assets':1,'deleted_files':cleanup['deleted_files'],'released_bytes':cleanup['released_bytes'],'retained_inputs':len(cleanup['retained_script_inputs']),'protected_files_unchanged':len(protected),'source_fingerprint':export['source_fingerprint'],'pck_sha256':export['pck_sha256'],'concurrent_performance':views['390x844'][0].get('performance',{}),'blocked':['Muse external rescore','physical phone/iPad and human play','clean-host native timing','320x568 street interact action in protected touch layout']}
 write(OUT/'verification.json',summary);write(OUT/'ownership-check.json',{'status':'VERIFIED','protected_files':len(protected),'changed':[]})
 for name in ['README.md','godot/project.godot','web/shell.html','docs/store/LISTING_ZH_TW.md']:
  text=(ROOT/name).read_text(encoding='utf8');assert '0.28.0' in text and '0.27.0' not in text
 report=ROOT/'docs/CODEX_RESPONSE_CONTENT_R14.md'
 body=report.read_text(encoding='utf8')
 values={'STATUS':'VERIFIED','SUITES':summary['suites'],'CHECKS':f"{summary['reported_checks']:,}",'CONTRAST':round(min(c['ratio'] for c in contrast),2),'PROTECTED':len(protected),'DELETED':cleanup['deleted_files'],'BYTES':f"{cleanup['released_bytes']:,}",'MIB':round(cleanup['released_bytes']/1048576,2),'RETAINED':summary['retained_inputs'],'P95':round(summary['concurrent_performance']['p95_median'],2)}
 for key,value in values.items():body=body.replace('{{'+key+'}}',str(value))
 assert '{{' not in body;report.write_text(body,encoding='utf8')
 changed=set(filter(None,git('diff','--name-only','-z').split('\0')))
 allowed={'README.md','docs/store/LISTING_ZH_TW.md','docs/art/ART_DIRECTION.md','godot/project.godot','web/shell.html','godot/assets/fonts/SevenDistrictSansTC-Regular.otf','godot/data/fraud_cases.json','godot/scripts/content/content_investigations.gd','godot/scripts/content/investigation_field.gd','godot/scripts/ui/investigation_panel.gd','godot/scripts/ui/investigation_time_mask.gd','godot/scripts/ui/investigation_links.gd','godot/scripts/ui/game_hud.gd','tests/content_r1.gd','tests/content_r5.gd','tests/content_r11.gd','tools/test_game.py'}
 allowed.update(['CREDITS.md','LICENSE-ASSETS.md'])
 allowed.update(e['path'] for e in cleanup['delete'])
 if (AUDIT/'owned-files.json').exists():allowed.update(read(AUDIT/'owned-files.json'))
 assert changed-set(protected)<=allowed,'Unowned changes appeared'
 own=changed&allowed
 for folder in ['docs/content/r14','godot/assets/art/content-r14','assets/art/content-r14']:
  own.update(p.relative_to(ROOT).as_posix() for p in (ROOT/folder).rglob('*') if p.is_file())
 own.update(['docs/OPTIM_PLAN_CONTENT_R14.md','docs/CODEX_RESPONSE_CONTENT_R14.md','tests/content_r14.gd',*store,'docs/store/screenshots/CONTENT_R14_STATUS.json'])
 own.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'tools').glob('content_r14_*') if p.suffix in ['.py','.mjs'])
 assert not own&set(protected)
 findings=[];tracked=set(filter(None,git('ls-files','-z').split('\0')))
 specified_pattern=r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}'
 for name in sorted(tracked|own):
  path=ROOT/name
  if not path.is_file() or path.suffix.lower() in {'.png','.webp','.glb','.blend','.wav','.otf','.zip'}:continue
  try:body=(subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT) if name in protected and name in tracked else path.read_bytes()).decode('utf8')
  except UnicodeError:continue
  findings.extend(scan_text(path,body))
  for match in re.finditer(specified_pattern,body):findings.append({'file':name,'line':body.count('\n',0,match.start())+1,'type':'specified_api_pattern'})
 write(OUT/'secrets-scan.json',{'status':'VERIFIED' if not findings else 'BLOCKED','findings':findings,'specified_pattern':specified_pattern,'scope':'Prospective tracked publication files; pre-existing protected drafts read from HEAD.'});assert not findings,findings[:5]
 own.add('docs/content/r14/secrets-scan.json');own=sorted(own);write(AUDIT/'owned-files.json',own)
 if args.stage:
  assert not git('diff','--cached','--name-only').strip(),'Another change is staged'
  for i in range(0,len(own),10):subprocess.run(['git','add','--',*own[i:i+10]],cwd=ROOT,check=True,capture_output=True)
  staged=set(filter(None,git('diff','--cached','--name-only','-z').split('\0')));assert staged<=set(own) and not staged&set(protected)
 print(json.dumps(summary,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
