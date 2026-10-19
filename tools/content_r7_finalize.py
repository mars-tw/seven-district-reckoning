"""Verify R7 native-size evidence and stage a precise owned-file allowlist."""
import argparse
from collections import Counter
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
OUT = ROOT/'docs/content/r7'
AUDIT = ROOT/'.audit-tmp/content-r7'
BASE = '''README.md CHANGELOG.md godot/project.godot web/shell.html godot/assets/fonts/SevenDistrictSansTC-Regular.otf godot/data/fraud_cases.json godot/scripts/content/content_investigations.gd godot/scripts/ui/investigation_panel.gd godot/scripts/ui/investigation_paper.gd tests/content_r1.gd tests/content_r2.gd tests/content_r3.gd tests/content_r4.gd tests/content_r5.gd tests/content_r6.gd tests/content_r7.gd tools/test_game.py tools/content_r7_prepare.py tools/content_r7_evidence.mjs tools/content_r7_finalize.py docs/store/LISTING_ZH_TW.md docs/OPTIM_PLAN_CONTENT_R7.md docs/CODEX_RESPONSE_CONTENT_R7.md'''.split()

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def write(p, value): (ROOT/p).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def verify(stage=False):
    for name in ['README.md','godot/project.godot','web/shell.html','docs/store/LISTING_ZH_TW.md']:
        text=(ROOT/name).read_text(encoding='utf8')
        assert '0.21.0' in text and '0.20.0' not in text, 'Active version stale: '+name
    owner = json.loads((AUDIT/'ownership.json').read_text(encoding='utf8'))['protected']
    assert all((ROOT/p).is_file() and sha(ROOT/p)==digest for p,digest in owner.items()), 'Owner draft changed'
    tests = read('docs/content/r7/final-tests.json')
    assert all(t['status']=='PASS' and not t['reported_failures'] for t in tests)
    assert len(tests)==2+len(SUITES)+len(JS_SUITES)
    exported = read('docs/content/r7/export.json')
    assert sha(AUDIT/'web/game.pck')==exported['pck_sha256'], 'Exported runtime bytes changed'
    assert sha(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')==exported['font_subset_sha256']
    assert tests[0]['source_fingerprint']==exported['source_fingerprint']
    assert source_fingerprint(AUDIT/'source/godot',AUDIT/'source/tests',AUDIT/'source/web',AUDIT/'source/tools')==exported['source_fingerprint']
    capture = read('docs/content/r7/manifest.json')
    assert capture['status']=='VERIFIED' and not capture['failures'] and len(capture['views'])==6
    assert {v['tag'] for v in capture['views']}=={'320x568','844x390','1024x768','1290x2796','2064x2752','390x844'}
    assert {'cjk_line_start','drag_preview_matches_drop','drag_cancel_preserves_order'} <= set(capture['guards'])
    assert capture['pck_sha256']==exported['pck_sha256']
    for view in capture['views']:
        for check in view['checks']:
            if 'fixture' in check:
                assert sha(AUDIT/'validated-saves'/(check['fixture']+'.json'))==check['sha256'], 'Captured fixture differs from final native-world fixture'
    glyphs = set()
    paths = set(BASE)
    for view in capture['views']:
        assert view['status']=='VERIFIED' and not view['errors'] and 'NVIDIA' in view['renderer']
        for shot in view['shots']:
            p = OUT/shot['file']
            assert sha(p)==shot['sha256'] and Image.open(p).size==tuple(map(int,view['tag'].split('x')))
            paths.add(p.relative_to(ROOT).as_posix())
            ui = shot['state']['investigations']['ui']
            glyphs.update(''.join(x['text'] for x in ui['buttons']+ui['labels']))
    phone = next(v for v in capture['views'] if v['tag']=='390x844')
    def shot(case,state): return next(s for s in phone['shots'] if s['file']==f'phone-{case}-{state}.png')
    def progress(case,state): return shot(case,state)['state']['investigations']['progress']['records'][case]
    for case in ['second_help','before_night','three_voices']:
        assert progress(case,'sealed')==progress(case,'reopened')==progress(case,'sealed-reloaded')
        assert progress(case,'sealed')['complete']
    assert not progress('second_help','action-payment-retry')['complete']
    assert not progress('second_help','action-accusation-retry')['complete']
    assert progress('second_help','sealed')['citations']=={'0':2,'1':2}
    assert not progress('before_night','relation-retry')['time_checked']
    assert progress('before_night','relations-chosen')['relations']=={'0':0,'1':1}
    for state in ['support-insufficient','support-one-side']:
        assert '1' not in progress('three_voices',state)['pin_choices']
    assert progress('three_voices','support-both-sides')['support_refs']==[0,2]
    for i in range(1,4):
        ui=shot('before_night',f'drag-preview-{i}')['state']['investigations']['ui']
        assert ui['dragging'] and ui['preview_slot']==i-1
        x,y,w,h=ui['ghost_rect']; a,b,c,d=ui['drop_zone']
        assert not (x<a+c and a<x+w and y<b+d and b<y+h), 'Ghost obscures drop area'
        assert any(x['text'].startswith('放下後：') for x in ui['labels'])
    font=TTFont(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')
    assert all(ord(c) in font.getBestCmap() for c in glyphs if not c.isspace() and c!='\u2060')
    font.close()
    selection=[
        ('second_help','paper-a-marked'),('second_help','action-options'),('second_help','action-payment-retry'),('second_help','sealed'),
        ('before_night','drag-preview-1'),('before_night','drag-preview-2'),('before_night','drag-preview-3'),('before_night','relations-chosen'),('before_night','sealed'),
        ('three_voices','wrong-pin'),('three_voices','support-insufficient'),('three_voices','support-both-sides'),('three_voices','player-results'),('three_voices','sealed'),
        ('','case-list-reloaded')]
    review_dir=OUT/'review-set'; review_dir.mkdir(exist_ok=True)
    review=[]
    for i,(case,state) in enumerate(selection,1):
        original=OUT/('phone-'+(case+'-' if case else '')+state+'.png')
        target=review_dir/f'{i:02d}-{case+"-" if case else ""}{state}.png'
        shutil.copy2(original,target)
        assert Image.open(target).size==(390,844) and sha(original)==sha(target)
        entry={'case':case or 'all','source':original.relative_to(ROOT).as_posix(),'file':target.relative_to(ROOT).as_posix(),'dimensions':[390,844],'sha256':sha(target)}
        review.append(entry); paths.add(entry['file'])
    assert len(list(review_dir.glob('*.png')))==15
    assert Counter(x['case'] for x in review)=={'second_help':4,'before_night':5,'three_voices':5,'all':1}
    write('docs/content/r7/review-set.json',{'status':'VERIFIED','method':'15 byte-identical original phone PNGs; no scaling or compositing. Four first-case, five second-case, five third-case, one all-case result list. 05-07 are continuous left/middle/right drag states.','images':review})
    store=[]
    for tag in ['1290x2796','2064x2752']:
        view=next(v for v in capture['views'] if v['tag']==tag)
        for name in ['before_night-relations-chosen','three_voices-support-both-sides']:
            source=next(s for s in view['shots'] if name in s['file'])
            target=ROOT/'docs/store/screenshots'/f'{tag}-content-r7-{name}.png'
            shutil.copy2(OUT/source['file'],target)
            assert Image.open(target).size==tuple(map(int,tag.split('x')))
            entry={'file':target.relative_to(ROOT).as_posix(),'source':'docs/content/r7/'+source['file'],'sha256':sha(target)}
            store.append(entry);paths.add(entry['file'])
    write('docs/store/screenshots/CONTENT_R7_STATUS.json',{'status':'VERIFIED','version':'0.21.0','new_screenshots':store,'existing_screenshots_deleted':False,'method':capture['method']})
    fixture_suite=next(t for t in tests if t['check']=='content_r4')
    (OUT/'fixture-tests.txt').write_text(fixture_suite['output'],encoding='utf8')
    fixtures=[]
    for p in sorted((AUDIT/'validated-saves').glob('*.json')):
        data=json.loads(p.read_text(encoding='utf8'))['data'];case=p.stem.split('-')[0];r=data['investigations']['records'][case]
        expected=int(p.stem.rsplit('-',1)[1]) if '-field-' in p.stem else (2 if case=='second_help' else 3)
        assert not r['complete'] and len(r['collected'])==expected
        fixtures.append({'file':p.name,'sha256':sha(p),'case':case,'collected':expected,'complete':False,'on_foot':data['player']['vehicle']==''})
    assert len(fixtures)==11 and all(f['on_foot'] for f in fixtures)
    write('docs/content/r7/fixture-generation.json',{'status':'VERIFIED','method':'Actual final headless content_r4 world interactions; only travel shortened. Browser finishes each uncompleted target using visible controls. Prior browser-completed cases retained.','source_fingerprint':fixture_suite['source_fingerprint'],'fixtures':fixtures})
    result={'status':'VERIFIED','version':'0.21.0','test_suites':len(tests)-1,'reported_checks':sum(t['reported_checks'] for t in tests),'failures':0,'protected_files_unchanged':len(owner),'browser_views':len(capture['views']),'screenshots':sum(len(v['shots']) for v in capture['views']),'review_images':15,'store_images':len(store),'generated_art_images':0,'displayed_glyphs_checked':len(glyphs),'source_digest':exported['source_fingerprint']['digest'],'pck_sha256':exported['pck_sha256'],'external_acceptance':'BLOCKED: Muse >=8 rescore, physical devices and human testing require actual reviewer/devices/testers.','performance':'Separate task per current line instruction; no p95 claim.'}
    for name in ['export.json','web-build.json','final-tests.json','manifest.json','review-set.json','fixture-generation.json','fixture-tests.txt','verification.json']:
        paths.add('docs/content/r7/'+name)
    paths.add('docs/store/screenshots/CONTENT_R7_STATUS.json')
    write('docs/content/r7/verification.json',result)
    assert not paths.intersection(owner) and all((ROOT/p).is_file() for p in paths)
    if stage:
        staged=set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode().split('\0'))-{''}
        assert not staged-paths, 'Unrelated staged files'
        names=sorted(paths)
        for i in range(0,len(names),40):subprocess.run(['git','add','--',*names[i:i+40]],cwd=ROOT,check=True)
        findings=[]; required_hits=0
        files=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
        for name in files:
            if not name or Path(name).suffix.lower() in {'.blend','.glb','.png','.otf','.wav','.zip','.webp'}:continue
            raw=subprocess.check_output(['git','show',':'+name],cwd=ROOT)
            try: text=raw.decode('utf8')
            except UnicodeError:continue
            findings.extend(scan_text(ROOT/name,text))
            required_hits+=len(re.findall(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}',text))
        assert not findings and required_hits==0, {'findings':findings,'required_pattern_hits':required_hits}
        result['secret_scan']={'status':'VERIFIED','scope':'Prospective index only; no credential-directory access.','tracked_files':len([x for x in files if x]),'findings':[],'required_pattern_hits':0}
        write('docs/content/r7/verification.json',result)
        subprocess.run(['git','add','--','docs/content/r7/verification.json'],cwd=ROOT,check=True)
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--stage',action='store_true')
    verify(parser.parse_args().stage)
