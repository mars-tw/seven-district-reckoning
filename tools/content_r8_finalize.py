"""Verify actual R8 artifacts and stage only a named, owned allowlist."""
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
OUT = ROOT / 'docs/content/r8'
AUDIT = ROOT / '.audit-tmp/content-r8'
BASE = '''README.md CHANGELOG.md godot/project.godot web/shell.html godot/assets/fonts/SevenDistrictSansTC-Regular.otf godot/data/fraud_cases.json godot/scripts/content/content_investigations.gd godot/scripts/ui/investigation_panel.gd godot/scripts/ui/investigation_rail.gd tests/content_r1.gd tests/content_r3.gd tests/content_r6.gd tests/content_r8.gd tools/test_game.py tools/content_r8_prepare.py tools/content_r8_evidence.mjs tools/content_r8_finalize.py docs/store/LISTING_ZH_TW.md docs/OPTIM_PLAN_CONTENT_R8.md docs/CODEX_RESPONSE_CONTENT_R8.md'''.split()

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf8'))
def write(path, data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def verify(stage=False):
    owner = read(AUDIT/'ownership.json')['protected']
    assert all((ROOT/p).is_file() and sha(ROOT/p)==digest for p,digest in owner.items()), 'Existing draft changed'
    for name in ['README.md','godot/project.godot','web/shell.html','docs/store/LISTING_ZH_TW.md']:
        text=(ROOT/name).read_text(encoding='utf8')
        assert '0.22.0' in text and '0.21.0' not in text, name
    tests=read(OUT/'final-tests.json')
    assert len(tests)==2+len(SUITES)+len(JS_SUITES)
    assert all(t['status']=='PASS' and t['reported_failures']==0 for t in tests)
    exported=read(OUT/'export.json')
    assert sha(AUDIT/'web/game.pck')==exported['pck_sha256']
    assert tests[0]['source_fingerprint']==exported['source_fingerprint']
    assert source_fingerprint(AUDIT/'source/godot',AUDIT/'source/tests',AUDIT/'source/web',AUDIT/'source/tools')==exported['source_fingerprint']
    assert sha(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')==exported['font_subset_sha256']
    capture=read(OUT/'manifest.json')
    assert capture['status']=='VERIFIED' and not capture['failures']
    assert {v['tag'] for v in capture['views']}=={'320x568','390x844','1290x2796','2064x2752'}
    assert capture['pck_sha256']==exported['pck_sha256']
    paths=set(BASE); glyphs=set()
    for view in capture['views']:
        assert view['status']=='VERIFIED' and not view['errors'] and 'NVIDIA' in view['renderer']
        for check in view['checks']:
            if 'fixture' in check:
                assert sha(AUDIT/'validated-saves'/(check['fixture']+'.json'))==check['sha256'], 'Fixture differs from final world-generated save'
        for shot in view['shots']:
            p=OUT/shot['file']; assert sha(p)==shot['sha256'] and Image.open(p).size==tuple(map(int,view['tag'].split('x')))
            paths.add(p.relative_to(ROOT).as_posix())
            ui=shot['state']['investigations']['ui']
            glyphs.update(''.join(x['text'] for x in ui['buttons']+ui['labels'])+ui.get('ghost_text',''))
    font=TTFont(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')
    assert all(ord(c) in font.getBestCmap() for c in glyphs if not c.isspace() and c!='\u2060'), 'Missing displayed glyph'
    font.close()
    phone=next(v for v in capture['views'] if v['tag']=='390x844')
    def shot(case,state): return next(s for s in phone['shots'] if s['file']==f'phone-{case}-{state}.png')
    def progress(case,state): return shot(case,state)['state']['investigations']['progress']['records'][case]
    for case in ['second_help','before_night','three_voices']:
        assert progress(case,'sealed')==progress(case,'sealed-reloaded')==progress(case,'history-reloaded')==progress(case,'chain-reloaded')
        assert progress(case,'sealed')['complete']
        ui=shot(case,'sealed-reloaded')['state']['investigations']['ui']
        assert any('你當時的選擇' in l['text'] for l in ui['labels'])
        assert not any(re.search('釘上|揭時核對|核對兩處黃標',b['text']) for b in ui['buttons'])
    actions=read(ROOT/'godot/data/fraud_cases.json')['cases'][0]['action_choices']
    assert max(map(len,actions))-min(map(len,actions))<=4
    for state in ['action-payment-retry','action-latest-only-retry']:
        p=progress('second_help',state); assert not p['complete'] and p['history'][-1]['feedback']
        assert '本案協助不收任何預付費。' in p['history'][-1]['feedback'] and '本案須先付代辦費，才受理協助。' in p['history'][-1]['feedback']
    for i in range(1,4):
        ui=shot('before_night',f'drag-preview-{i}')['state']['investigations']['ui']
        expected=[[0,2,1],[2,0,1],[2,1,0]][i-1]
        assert ui['dragging'] and ui['preview_slot']==i-1 and ui['slot_order']==expected
        assert progress('before_night',f'actual-drop-{i}')['order']==expected
        assert '時間：〔遮蔽〕' in ui['ghost_text'] and '這張收據供摘要引用' in ui['ghost_text']
        x,y,w,h=ui['ghost_rect']; a,b,c,d=ui['drop_zone']
        assert not (x<a+c and a<x+w and y<b+d and b<y+h)
    for state in ['relations-empty','relations-one']:
        ui=shot('before_night',state)['state']['investigations']['ui']
        assert next(b for b in ui['buttons'] if b['text']=='揭時核對')['disabled']
    for count in range(4):
        ui=shot('before_night',f'placed-{count}')['state']['investigations']['ui']
        captions=[l['text'] for l in ui['labels'] if '待放原件' in l['text'] or '原件已全放入' in l['text']]
        assert len(captions)==1
    assert progress('three_voices','support-one-side')['support_refs']==[0]
    assert '1' not in progress('three_voices','support-one-side')['pin_choices']
    wrong=shot('three_voices','wrong-pin')['state']['investigations']['ui']
    assert any('錯釘' in l['text'] and '應反駁陳' in l['text'] for l in wrong['labels'])
    selection=[
        ('second_help','field-0'),('second_help','paper-b-marked'),('second_help','action-options'),('second_help','action-payment-retry'),('second_help','history-reloaded'),
        ('before_night','drag-preview-1'),('before_night','drag-preview-2'),('before_night','drag-preview-3'),('before_night','actual-drop-3'),('before_night','relations-one'),('before_night','relations-chosen'),
        ('three_voices','wrong-pin'),('three_voices','support-one-side'),('three_voices','support-both-sides'),('three_voices','chain-reloaded')]
    review_dir=OUT/'review-set'; review_dir.mkdir(exist_ok=True); review=[]
    for i,(case,state) in enumerate(selection,1):
        original=OUT/f'phone-{case}-{state}.png'; target=review_dir/f'{i:02d}-{case}-{state}.png'
        shutil.copy2(original,target)
        assert Image.open(target).size==(390,844) and sha(original)==sha(target)
        entry={'case':case,'source':original.relative_to(ROOT).as_posix(),'file':target.relative_to(ROOT).as_posix(),'dimensions':[390,844],'sha256':sha(target)}
        review.append(entry); paths.add(entry['file'])
    assert len(list(review_dir.glob('*.png')))==15
    write(OUT/'review-set.json',{'status':'VERIFIED','method':'15 byte-identical native phone PNGs, no resizing, compositing or retouching. Five first-case, six sorting-case and four testimony-case images; three consecutive drag positions plus actual release. Supplemental captures retain all three exact drop results and archive pages.','images':review})
    store=[]
    for tag in ['1290x2796','2064x2752']:
        view=next(v for v in capture['views'] if v['tag']==tag)
        for name in ['before_night-relations-chosen','three_voices-support-both-sides']:
            source=next(s for s in view['shots'] if name in s['file'])
            target=ROOT/'docs/store/screenshots'/f'{tag}-content-r8-{name}.png'
            shutil.copy2(OUT/source['file'],target); assert Image.open(target).size==tuple(map(int,tag.split('x')))
            entry={'file':target.relative_to(ROOT).as_posix(),'source':'docs/content/r8/'+source['file'],'sha256':sha(target)}
            store.append(entry); paths.add(entry['file'])
    write(ROOT/'docs/store/screenshots/CONTENT_R8_STATUS.json',{'status':'VERIFIED','version':'0.22.0','new_screenshots':store,'existing_screenshots_deleted':False})
    paths.add('docs/store/screenshots/CONTENT_R8_STATUS.json')
    fixture_suite=next(t for t in tests if t['check']=='content_r4')
    fixtures=[{'file':p.name,'sha256':sha(p)} for p in sorted((AUDIT/'validated-saves').glob('*.json'))]
    assert len(fixtures)==11
    write(OUT/'fixture-generation.json',{'status':'VERIFIED','method':'Final headless content_r4 actual world interactions; target remains unfinished. Only travel is shortened for subsequent visible browser operations.','source_fingerprint':fixture_suite['source_fingerprint'],'fixtures':fixtures})
    result={'status':'VERIFIED','version':'0.22.0','test_suites':len(tests)-1,'reported_checks':sum(t['reported_checks'] for t in tests),'failures':0,'protected_files_unchanged':len(owner),'browser_views':len(capture['views']),'screenshots':len({s['file'] for v in capture['views'] for s in v['shots']}),'review_images':15,'store_images':len(store),'generated_art_images':0,'displayed_glyphs_checked':len(glyphs),'pck_sha256':exported['pck_sha256'],'performance':phone.get('performance',{}),'external_acceptance':'BLOCKED: actual Muse rescore >=8, physical devices and human testing require external reviewer/devices/testers.'}
    for name in ['export.json','web-build.json','final-tests.json','manifest.json','review-set.json','fixture-generation.json','verification.json']:
        paths.add('docs/content/r8/'+name)
    write(OUT/'verification.json',result)
    assert not paths.intersection(owner) and all((ROOT/p).is_file() for p in paths)
    write(AUDIT/'owned-paths.json',sorted(paths))
    if stage:
        staged=set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode().split('\0'))-{''}
        assert not staged-paths, 'Unrelated staged files must remain outside this commit'
        names=sorted(paths)
        for i in range(0,len(names),10): subprocess.run(['git','add','--',*names[i:i+10]],cwd=ROOT,check=True)
        text_files=[]
        for name in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0'):
            if name and Path(name).suffix.lower() not in {'.blend','.glb','.png','.otf','.wav','.zip','.webp'}: text_files.append(name)
        # Read prospective Git index blobs only; never inspect a credentials directory.
        proc=subprocess.run(['git','cat-file','--batch'],cwd=ROOT,input=''.join(':'+n+'\n' for n in text_files).encode(),capture_output=True,check=True)
        data=proc.stdout; offset=0; findings=0; pattern_hits=0
        for name in text_files:
            end=data.index(b'\n',offset); header=data[offset:end].split(); length=int(header[2]); offset=end+1
            blob=data[offset:offset+length]; offset+=length+1
            try: text=blob.decode('utf8')
            except UnicodeError: continue
            findings+=len(scan_text(ROOT/name,text))
            pattern_hits+=len(re.findall(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}',text))
        assert findings==0 and pattern_hits==0, 'Secret scanner found nonzero matches; values suppressed'
        result['secret_scan']={'status':'VERIFIED','scope':'Prospective Git index blobs only','text_files':len(text_files),'findings':findings,'required_pattern_hits':pattern_hits}
        write(OUT/'verification.json',result)
        subprocess.run(['git','add','--','docs/content/r8/verification.json'],cwd=ROOT,check=True)
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--stage',action='store_true')
    verify(parser.parse_args().stage)
