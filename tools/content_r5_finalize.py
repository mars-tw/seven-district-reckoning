"""Validate source-bound R5 evidence, copy native review/store PNGs and stage only owned files."""
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
from test_game import SUITES, JS_SUITES, source_fingerprint

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/content/r5'
BASE = '''README.md godot/project.godot web/shell.html godot/assets/fonts/SevenDistrictSansTC-Regular.otf godot/data/fraud_cases.json godot/scripts/content/content_investigations.gd godot/scripts/ui/investigation_panel.gd godot/scripts/ui/investigation_paper.gd godot/scripts/ui/investigation_paper.gd.uid godot/scripts/ui/investigation_rail.gd godot/scripts/ui/investigation_rail.gd.uid godot/scripts/ui/game_hud.gd tests/content_r1.gd tests/content_r3.gd tests/content_r5.gd tools/test_game.py tools/content_r5_prepare.py tools/content_r5_evidence.mjs tools/content_r5_finalize.py docs/OPTIM_PLAN_CONTENT_R5.md docs/CODEX_RESPONSE_CONTENT_R5.md'''.split()

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def write(p,value):
    (ROOT/p).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def verify(stage=False):
    owner=read('.audit-tmp/content-r5/ownership.json')
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).decode().strip()==owner['branch']
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()==owner['head']
    assert all((ROOT/p).is_file() and sha(ROOT/p)==h for p,h in owner['protected'].items()), 'Protected file changed'
    tests=read('docs/content/r5/final-tests.json')
    assert len(tests)==len(SUITES)+len(JS_SUITES)+2 and all(t['status']=='PASS' for t in tests)
    exported=read('docs/content/r5/export.json')
    assert exported['pck_bytes']<=25*1024*1024
    assert all(t['source_fingerprint']['digest']==exported['source_fingerprint']['digest'] for t in tests)
    source=ROOT/'.audit-tmp/content-r5/source'
    assert source_fingerprint(source/'godot',source/'tests',source/'web',source/'tools')['digest']==exported['source_fingerprint']['digest']
    for parent in ['godot','tests','web']:
        for p in (source/parent).rglob('*'):
            if not p.is_file() or any(x in {'.godot','_checks'} for x in p.relative_to(source).parts):continue
            if not (p.suffix in {'.gd','.json','.gdshader','.tscn','.css','.js','.html','.cfg'} or p.name=='project.godot'):continue
            name=p.relative_to(source).as_posix()
            expected=subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT) if name in owner['protected'] else (ROOT/name).read_bytes()
            assert p.read_bytes()==expected,'Source drift '+name
    assert sha(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')==exported['font_subset_sha256']
    capture=read('docs/content/r5/manifest.json')
    assert capture['status']=='VERIFIED' and len(capture['views'])==6 and not capture['failures']
    assert 'label_overlap' in capture['guards']
    assert capture['pck_sha256']==exported['pck_sha256']
    assert {p.name for p in OUT.glob('*.png')}=={s['file'] for v in capture['views'] for s in v['shots']}, 'Unregistered or interim PNG'
    displayed=set()
    for view in capture['views']:
        assert view['status']=='VERIFIED' and not view['errors'] and 'NVIDIA' in view['renderer']
        assert any(c.get('indexeddb_cold_reload')=='VERIFIED' for c in view['checks'])
        assert {c['case'] for c in view['checks'] if c.get('completed')}=={'second_help','before_night','three_voices'}
        assert any(c.get('paper_citations_saved') for c in view['checks'])
        for shot in view['shots']:
            p=OUT/shot['file']
            assert sha(p)==shot['sha256']
            assert Image.open(p).size==(view['viewport']['width']*view['dpr'],view['viewport']['height']*view['dpr'])
            ui=shot['state']['investigations']['ui']
            texts=[b['text'] for b in ui['buttons']+ui['labels']]
            if re.search(r'before_night-(unsorted|shuffled|drag-preview|sorting|middle-to-left|arranged|tap-alternative)',shot['file']):
                assert not re.search(r'17[：:]42|17[：:]55|18[：:]00',' '.join(texts)), 'Time leak'
            for value in texts:
                assert '\ufffd' not in value and '□' not in value and not re.search(r'\?{3,}',value)
                displayed.update(c for c in value if not c.isspace() and c!='\u2060')
    phone=next(v for v in capture['views'] if v['tag']=='390x844')
    previews=[next(s for s in phone['shots'] if s['file']==f'phone-before_night-drag-preview-{i}.png') for i in [1,2,3]]
    assert [s['state']['investigations']['ui']['preview_slot'] for s in previews]==[0,1,2]
    assert all(s['state']['investigations']['ui']['dragging'] for s in previews)
    assert len({s['sha256'] for s in previews})==3
    font=TTFont(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')
    assert all(ord(c) in font.getBestCmap() for c in displayed), 'Missing displayed glyph'
    font.close()
    selection=[
        ('second_help','paper-a-unmarked'),('second_help','paper-a-reloaded'),
        ('second_help','paper-b-unmarked'),('second_help','paper-b-marked'),('second_help','spread-before-seal'),
        ('before_night','drag-preview-1'),('before_night','drag-preview-2'),('before_night','drag-preview-3'),
        ('before_night','middle-to-left'),('before_night','attachment-picked'),
        ('three_voices','original-0'),('three_voices','original-1'),('three_voices','original-2'),
        ('three_voices','pinning-last'),('three_voices','sealed')]
    review_dir=OUT/'review-set';review_dir.mkdir(exist_ok=True)
    review=[]
    for i,(case,state) in enumerate(selection,1):
        original=OUT/f'phone-{case}-{state}.png';target=review_dir/f'{i:02d}-{case}-{state}.png'
        shutil.copy2(original,target)
        w,h=Image.open(target).size
        assert h>w and sha(original)==sha(target)
        review.append({'case':case,'source':original.relative_to(ROOT).as_posix(),'file':target.relative_to(ROOT).as_posix(),'dimensions':[w,h],'sha256':sha(target)})
    assert len(list(review_dir.glob('*.png')))==15 and Counter(x['case'] for x in review)=={'second_help':5,'before_night':5,'three_voices':5}
    write('docs/content/r5/review-set.json',{'status':'VERIFIED','method':'Byte-identical copies of original phone PNGs; five per case. 06-08 are the same card dragged across three exact drop previews; 02 follows an actual IndexedDB cold reload. No compositing or resizing.','images':review})
    store=[]
    for tag in ['1290x2796','2064x2752']:
        view=next(v for v in capture['views'] if v['tag']==tag)
        for name in ['before_night-attachment-picked','three_voices-statement-2']:
            shot=next(s for s in view['shots'] if name in s['file'])
            target=ROOT/'docs/store/screenshots'/(tag+'-content-r5-'+name+'.png')
            shutil.copy2(OUT/shot['file'],target)
            assert Image.open(target).size==tuple(map(int,tag.split('x')))
            store.append({'file':target.relative_to(ROOT).as_posix(),'sha256':sha(target),'source':'docs/content/r5/'+shot['file']})
    write('docs/store/screenshots/CONTENT_R5_STATUS.json',{'status':'VERIFIED','version':'0.19.0','new_screenshots':store,'existing_screenshots_deleted':False,'method':capture['method']})
    write('docs/content/r5/limitations.json',{'status':'BLOCKED','items':['Muse independent rescore >=8 requires the reviewer; no score invented.','Physical iPhone/iPad/Android and human blind recognition require actual devices and testers.'],'performance':'Deferred to the separate task by the current line instruction; no p95 claim.','new_generated_art':0,'art':'Existing licensed/generated paper, document illustrations, storefronts, models and animations reused; new ink hit targets, insertion marks and record rails are functional UI.'})
    result={'status':'VERIFIED','version':'0.19.0','test_suites':len(tests)-1,'reported_checks':sum(t['reported_checks'] for t in tests),'failures':0,'protected_files_unchanged':len(owner['protected']),'browser_views':len(capture['views']),'screenshots':sum(len(v['shots']) for v in capture['views']),'review_images':15,'store_screenshots':len(store),'generated_art_images':0,'displayed_glyphs_checked':len(displayed),'pck_sha256':exported['pck_sha256'],'pck_bytes':exported['pck_bytes'],'source_digest':exported['source_fingerprint']['digest'],'external_acceptance':'BLOCKED: Muse rescore, physical devices and human testing pending.'}
    write('docs/content/r5/verification.json',result)
    paths=set(BASE)
    paths.update('docs/content/r5/'+n for n in ['export.json','web-build.json','final-tests.json','manifest.json','review-set.json','limitations.json','verification.json','REVIEW_GALLERY.md','fixture-generation.json','fixture-tests.txt','test-driver-update.json'])
    paths.update('docs/content/r5/'+s['file'] for v in capture['views'] for s in v['shots'])
    paths.update(x['file'] for x in review)
    paths.update(x['file'] for x in store)
    paths.add('docs/store/screenshots/CONTENT_R5_STATUS.json')
    assert not paths.intersection(owner['protected'])
    assert all((ROOT/p).is_file() for p in paths)
    if stage:
        staged=set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode().split('\0'))-{''}
        assert not staged-paths,'Unrelated index entries'
        names=sorted(paths)
        for i in range(0,len(names),40):subprocess.run(['git','add','--',*names[i:i+40]],cwd=ROOT,check=True)
        findings=[];required_hits=0
        files=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
        for name in files:
            if not name or Path(name).suffix.lower() in {'.blend','.glb','.png','.otf','.wav','.zip','.webp'}:continue
            raw=subprocess.check_output(['git','show',':'+name],cwd=ROOT)
            try:text=raw.decode('utf8')
            except UnicodeError:continue
            findings.extend(scan_text(ROOT/name,text))
            required_hits+=len(re.findall(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}',text))
        assert not findings and required_hits==0,{'findings':findings,'required_pattern_hits':required_hits}
        result['secret_scan']={'status':'VERIFIED','scope':'Prospective index only; protected drafts and credential directories excluded.','tracked_files':len([x for x in files if x]),'findings':[],'required_pattern_hits':0}
        write('docs/content/r5/verification.json',result)
        subprocess.run(['git','add','--','docs/content/r5/verification.json'],cwd=ROOT,check=True)
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage',action='store_true')
    verify(parser.parse_args().stage)
