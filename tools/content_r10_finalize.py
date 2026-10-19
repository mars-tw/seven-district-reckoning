"""Verify R10 source, native/web evidence and unchanged drafts; stage explicit files."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
from PIL import Image
from fontTools.ttLib import TTFont
from scan_publication import scan_text
from test_game import source_fingerprint, SUITES, JS_SUITES

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/content/r10'
AUDIT = ROOT / '.audit-tmp/content-r10'
BASE = '''README.md CHANGELOG.md docs/art/ART_DIRECTION.md docs/store/LISTING_ZH_TW.md
godot/project.godot web/shell.html godot/assets/fonts/SevenDistrictSansTC-Regular.otf
godot/data/fraud_cases.json godot/scripts/content/content_investigations.gd
godot/scripts/content/investigation_field.gd godot/scripts/main.gd godot/scripts/ui/game_hud.gd
godot/scripts/ui/investigation_panel.gd godot/scripts/ui/investigation_paper.gd
godot/scripts/ui/investigation_rail.gd tests/content_r1.gd tests/content_r6.gd tests/content_r8.gd tests/content_r10.gd godot/scripts/ui/investigation_links.gd godot/scripts/ui/investigation_links.gd.uid
tools/test_game.py tools/content_r10_prepare.py tools/content_r10_evidence.mjs tools/content_r10_finalize.py
docs/OPTIM_PLAN_CONTENT_R10.md docs/CODEX_RESPONSE_CONTENT_R10.md docs/content/r10/review-set/README.md'''.split()

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf8'))
def write(path, data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def merge_capture(names):
    """Retain only genuinely verified views; require every view after reruns."""
    reports=[]; runs=[]; views={}
    for name in names:
        path=(ROOT/name).resolve(); assert path.is_relative_to(ROOT)
        report=read(path); reports.append(report)
        runs.append({'manifest_sha256':sha(path),'original_status':report['status'],
                     'verified_views':[v['tag'] for v in report['views'] if v.get('status')=='VERIFIED'],
                     'failed_views':[v['tag'] for v in report['views'] if v.get('status')=='BLOCKED']})
        for view in report['views']:
            if view.get('status')=='VERIFIED':
                assert view['tag'] not in views, 'Duplicate verified view'
                views[view['tag']]=view
    assert len({r['pck_sha256'] for r in reports})==1, 'Cannot combine different exports'
    order=['390x844','320x568','1290x2796','2064x2752','844x390','1024x768']
    assert set(views)==set(order), 'A rerun is still missing'
    result=dict(reports[0],status='VERIFIED',failures=[],views=[views[t] for t in order],capture_runs=runs)
    result['rerun_note']='Verified views of one identical export only. Earlier failed captures are retained locally in .audit-tmp/content-r10/iterations and excluded from final proof. All gameplay, layout, phrase and reload guards remain enabled.'
    write(OUT/'manifest.json',result)

def verify(stage=False):
    protected = read(AUDIT/'ownership.json')['protected']
    assert all((ROOT/p).is_file() and sha(ROOT/p)==digest for p,digest in protected.items()), 'Pre-existing draft changed'
    tests = read(OUT/'final-tests.json')
    assert len(tests) == 2+len(SUITES)+len(JS_SUITES)
    assert all(t['status']=='PASS' and t['reported_failures']==0 for t in tests), 'Native checks failed'
    export = read(OUT/'export.json')
    fingerprint = source_fingerprint(AUDIT/'source/godot',AUDIT/'source/tests',AUDIT/'source/web',AUDIT/'source/tools')
    assert export['source_fingerprint'] == fingerprint == tests[0]['source_fingerprint'], 'Test/export source mismatch'
    assert export['pck_sha256'] == sha(AUDIT/'web/game.pck')
    assert export['font_subset_sha256'] == sha(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')
    capture = read(OUT/'manifest.json')
    assert capture['status']=='VERIFIED' and not capture['failures']
    assert capture['pck_sha256'] == export['pck_sha256']
    assert {v['tag'] for v in capture['views']} == {'390x844','320x568','1290x2796','2064x2752','844x390','1024x768'}
    glyphs = set(); images = set(); red = []
    for view in capture['views']:
        assert view['status']=='VERIFIED' and not view['errors']
        assert 'NVIDIA' in view['renderer'] and 'SwiftShader' not in view['renderer']
        assert any(c.get('indexeddb_cold_reload')=='VERIFIED' for c in view['checks'])
        for shot in view['shots']:
            file = OUT/shot['file']; assert sha(file)==shot['sha256']
            with Image.open(file) as im: assert im.size == tuple(map(int,view['tag'].split('x')))
            images.add('docs/content/r10/'+shot['file'])
            ui = shot['state']['investigations']['ui']
            for ink in ui['buttons']+ui['labels']:
                glyphs.update(ink['text'])
                assert not any(re.fullmatch(r'[\u4e00-\u9fff][。，：；？！、」』）]?',line) for line in ink['rendered_text'].split('\n')), (shot['file'],ink['text'])
            glyphs.update(ui.get('ghost_text',''))
            for b in ui['buttons']:
                if b['selected']: assert b['background']=='f1e8d5ff', (shot['file'],b['text'])
            for label in ui['labels']:
                if label['color'] in ['c4271cff','8e1b12ff']: red.append({'file':shot['file'],'text':label['text']})
    font=TTFont(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')
    assert all(ord(c) in font.getBestCmap() for c in glyphs if not c.isspace() and c!='\u2060'), 'Missing displayed glyph'
    font.close()
    phone = next(v for v in capture['views'] if v['tag']=='390x844')
    def shot(name): return next(s for s in phone['shots'] if s['file']=='phone-'+name+'.png')
    for case in ['second_help','before_night','three_voices']:
        original = shot(case+'-sealed')['state']['investigations']['progress']['records'][case]
        assert original['complete']
        for state in ['sealed-reloaded','chain-reloaded','history-reloaded']:
            assert shot(case+'-'+state)['state']['investigations']['progress']['records'][case] == original
    for choice,kind in enumerate(['actual','payment-replay','latest-replay']):
        s=shot('second_help-street-'+kind)['state']['investigations']
        assert s['street_result']['count'] == s['street_objects']['objects'] == (1 if choice==2 else 2)
        assert s['progress']['records']['second_help']['complete']
        assert s['street_result']['replay'] == (choice>0)
        assert s['street_objects']['replay_mark'] == (choice>0), 'Persistent replay mark must follow actual/replay state'
    wrong=shot('before_night-relation-retry')['state']['investigations']
    repaired=shot('before_night-relations-chosen')['state']['investigations']
    assert wrong['ui']['page']=='relations'
    assert not any('✓' in item['text'] for item in wrong['ui']['buttons']+wrong['ui']['labels'])
    assert next(b for b in wrong['ui']['buttons'] if b['text']=='揭時核對')['disabled']
    assert not next(b for b in repaired['ui']['buttons'] if b['text']=='揭時核對')['disabled']
    assert any('你選的：交接摘要 → 車店收據' in l['text'] and '應為：車店收據 → 交接摘要' in l['text'] for l in wrong['ui']['labels'])
    assert wrong['progress']['records']['before_night']['relations']=={'0':1,'1':1}
    assert repaired['progress']['records']['before_night']['relations']=={'0':0,'1':1}
    second_wrong=shot('before_night-relation-b-retry')['state']['investigations']
    assert second_wrong['progress']['records']['before_night']['relations']=={'0':0,'1':0}
    assert any('接班依據' in l['text'] and '你選的' in l['text'] and '應為' in l['text'] for l in second_wrong['ui']['labels'])
    mask_states=[shot('before_night-'+name)['state']['investigations']['ui']['revealed_cards'] for name in ['revealing-1','revealing-2','revealed']]
    assert 0<=mask_states[0]<mask_states[1]<mask_states[2]==3, 'Sequential real time-mask proof'
    for index in range(1,4):
        ui=shot('before_night-drag-preview-'+str(index))['state']['investigations']['ui']
        assert ui['dragging'] and ui['preview_slot']==index-1
        assert ui['slot_order']==[[0,2,1],[2,0,1],[2,1,0]][index-1]
        assert ui['ghost_text'].count('時間被遮蔽') == 1 and '這張收據供摘要引用' in ui['ghost_text']
        x,y,w,h=ui['ghost_rect']; a,b,c,d=ui['drop_zone']
        px,py,pw,ph=ui['paper_rect']
        assert x>=px+8 and y>=py+8 and x+w<=px+pw-8 and y+h<=py+ph-8
        assert y>=0 and not (x<a+c and a<x+w and y<b+d and b<y+h)
    assert shot('three_voices-support-one-side')['state']['investigations']['progress']['records']['three_voices']['support_refs']==[0]
    assert shot('three_voices-support-last-only')['state']['investigations']['progress']['records']['three_voices']['support_refs']==[2]
    for view in capture['views']:
        for entry in view['shots']:
            for ink in entry['state']['investigations']['ui']['buttons']+entry['state']['investigations']['ui']['labels']:
                for term in ['車店收據','輪值資料','交接摘要','工作天','原件影本','前後合看','甲先發','乙後補']:
                    assert ink['rendered_text'].count(term)==ink['text'].count(term), ('Broken phrase',entry['file'],term)
    small=next(v for v in capture['views'] if v['tag']=='320x568')
    for i in range(1,4):
        ui=next(s for s in small['shots'] if s['file']==f'phone-before_night-drag-preview-{i}-320x568.png')['state']['investigations']['ui']
        x,y,w,h=ui['ghost_rect']; px,py,pw,ph=ui['paper_rect']
        assert x>=px+8 and y>=py+8 and x+w<=px+pw-8 and y+h<=py+ph-8
    unpinned=shot('three_voices-local-pin-unpinned')['state']['investigations']['progress']['records']['three_voices']
    assert set(unpinned['pins'])=={1,2} and '0' not in unpinned['pin_choices']
    assert unpinned['pin_choices']['1']==2 and unpinned['pin_choices']['2']==0 and set(unpinned['support_refs'])=={0,2}
    write(OUT/'acceptance.json',{'status':'VERIFIED','wrong_arrow_disables_reveal':True,'explicit_player_and_correct_directions':True,'local_link_repair_preserves_other_link':True,'paper_safe_drag_390_and_320':True,'protected_phrases_not_split':True,'time_mask_frames':mask_states,'persistent_replay_mark':True,'local_unpin_preserves_other_two':True,'muse_rescore':'BLOCKED: independent review not performed'})
    selection = [
        'second_help-paper-b-marked','second_help-action-payment-retry','second_help-action-latest-only-retry','second_help-street-payment-replay','second_help-street-actual',
        'before_night-drag-preview-1','before_night-drag-preview-3','before_night-relation-retry','before_night-relations-chosen','before_night-attachment-picked',
        'three_voices-support-one-side','three_voices-support-last-only','three_voices-support-both-sides','three_voices-local-pin-unpinned','three_voices-chain-reloaded']
    review_dir=OUT/'review-set'; review_dir.mkdir(exist_ok=True); review=[]
    for i,name in enumerate(selection,1):
        original=OUT/('phone-'+name+'.png'); target=review_dir/f'{i:02d}-{name}.png'
        shutil.copy2(original,target); assert sha(original)==sha(target)
        with Image.open(target) as im: assert im.size==(390,844)
        review.append({'file':target.relative_to(ROOT).as_posix(),'original':original.relative_to(ROOT).as_posix(),'sha256':sha(target)})
    assert len(list(review_dir.glob('*.png')))==15
    write(OUT/'review-set.json',{'status':'VERIFIED','images':review,'counts':{'second_help':5,'before_night':5,'three_voices':5},'resized_or_composited':False})
    write(OUT/'red-text.json',{'status':'VERIFIED','meaning':'Incorrect choice, contradictory source phrase, or missing reference only. No neutral/success/archive titles.','occurrences':red})
    store=[]
    for tag in ['1290x2796','2064x2752']:
        original=OUT/(('phone-before_night-relations-chosen-'+tag) if tag=='1290x2796' else tag+'-before_night-relations-chosen')
        original=original.with_suffix('.png')
        target=ROOT/'docs/store/screenshots'/f'{tag}-content-r10-before_night-relations-chosen.png'
        shutil.copy2(original,target); assert sha(original)==sha(target)
        store.append(target.relative_to(ROOT).as_posix())
    write(ROOT/'docs/store/screenshots/CONTENT_R10_STATUS.json',{'status':'VERIFIED','version':'0.24.0','new_screenshots':store,'existing_screenshots_deleted':False})
    write(OUT/'ownership-check.json',{'status':'VERIFIED','protected_files':len(protected),'changed':[]})
    for name in ['README.md','godot/project.godot','web/shell.html','docs/store/LISTING_ZH_TW.md']:
        text=(ROOT/name).read_text(encoding='utf8'); assert '0.24.0' in text and '0.23.0' not in text
    generated=['docs/content/r10/'+p.name for p in OUT.glob('*.json') if p.name not in ['initial-tests.json','interim-tests.json']]
    files=sorted(set(BASE+list(images)+[r['file'] for r in review]+generated+store+['docs/store/screenshots/CONTENT_R10_STATUS.json','docs/content/r10/verification.json','docs/content/r10/secrets-scan.json']))
    assert not set(files)&set(protected)
    result={'status':'VERIFIED','version':'0.24.0','automated_suites':len(tests)-1,'native_engine_suites':len(tests)-1-len(JS_SUITES),'reported_checks':sum(t['reported_checks'] for t in tests),'failures':0,'web_views':len(capture['views']),'screenshots':len(images),'review_images':15,'store_images':len(store),'new_generated_images':0,'protected_files_unchanged':len(protected),'source_fingerprint':fingerprint,'pck_sha256':export['pck_sha256'],'concurrent_reference_performance':phone.get('performance',{}),'external_acceptance':'BLOCKED: physical devices, human testing, clean native timings and actual external Muse rescore require external conditions.'}
    write(OUT/'verification.json',result)
    # Scan prospective publication text without including unrelated owner drafts.
    tracked=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0')
    findings=[]
    for name in sorted(set(tracked+files)):
        if not name: continue
        p=ROOT/name
        if not p.is_file() or p.suffix.lower() in ['.png','.webp','.glb','.blend','.wav','.otf','.zip']: continue
        try: text=(subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT) if name in protected else p.read_bytes()).decode('utf8')
        except UnicodeError: continue
        findings.extend(scan_text(p,text))
    write(OUT/'secrets-scan.json',{'status':'VERIFIED' if not findings else 'BLOCKED','files':len(set(tracked+files)),'findings':findings})
    assert not findings,'Prospective text scan failed'
    (AUDIT/'owned-files.json').write_text(json.dumps(files,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    if stage:
        assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=ROOT).strip(), 'Index already contains unrelated changes'
        for start in range(0,len(files),10): subprocess.run(['git','add','--',*files[start:start+10]],cwd=ROOT,check=True)
        staged=subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0')
        assert set(filter(None,staged))<=set(files)
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--stage',action='store_true')
    p.add_argument('--merge-manifest',action='append',default=[])
    args=p.parse_args()
    if args.merge_manifest: merge_capture(args.merge_manifest)
    verify(args.stage)
