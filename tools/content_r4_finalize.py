"""Verify R4 evidence, copy the fifteen native-size review images and stage owned paths."""
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
OUT = ROOT/'docs/content/r4'
BASE = '''README.md CREDITS.md godot/project.godot web/shell.html godot/assets/fonts/SevenDistrictSansTC-Regular.otf godot/data/fraud_cases.json godot/scripts/ui/investigation_panel.gd godot/scripts/content/content_investigations.gd godot/scripts/content/investigation_field.gd godot/scripts/content/taiwan_world.gd tests/content_r3.gd tests/content_r4.gd tools/test_game.py tools/content_r4_prepare.py tools/content_r4_evidence.mjs tools/content_r4_finalize.py docs/OPTIM_PLAN_CONTENT_R4.md docs/CODEX_RESPONSE_CONTENT_R4.md'''.split()

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def write(p, value):
    (ROOT/p).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def verify(stage=False):
    owner = read('.audit-tmp/content-r4/ownership.json')
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).decode().strip() == owner['branch']
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip() == owner['head']
    assert all((ROOT/p).is_file() and sha(ROOT/p) == h for p,h in owner['protected'].items()), 'Owner file changed'
    tests = read('docs/content/r4/final-tests.json')
    assert len(tests) == len(SUITES)+len(JS_SUITES)+2 and all(t['status']=='PASS' for t in tests)
    exported = read('docs/content/r4/export.json')
    assert exported['pck_bytes'] <= 25*1024*1024
    assert all(t['source_fingerprint']['digest'] == exported['source_fingerprint']['digest'] for t in tests)
    source = ROOT/'.audit-tmp/content-r4/source'
    assert source_fingerprint(source/'godot',source/'tests',source/'web',source/'tools')['digest'] == exported['source_fingerprint']['digest']
    for parent in ['godot','tests','web']:
        for p in (source/parent).rglob('*'):
            if not p.is_file() or any(x in {'.godot','_checks'} for x in p.relative_to(source).parts): continue
            if not (p.suffix in {'.gd','.json','.gdshader','.tscn','.css','.js','.html','.cfg'} or p.name == 'project.godot'): continue
            name = p.relative_to(source).as_posix()
            expected = subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT) if name in owner['protected'] else (ROOT/name).read_bytes()
            assert p.read_bytes() == expected, 'Source drift '+name
    assert sha(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf') == exported['font_subset_sha256']
    capture = read('docs/content/r4/manifest.json')
    assert capture['status']=='VERIFIED' and len(capture['views'])==6 and not capture['failures']
    assert capture['pck_sha256'] == exported['pck_sha256']
    paths = set(BASE)
    displayed = set()
    motion = []
    for view in capture['views']:
        assert view['status']=='VERIFIED' and not view['errors'] and 'NVIDIA' in view['renderer']
        assert any(c.get('indexeddb_cold_reload')=='VERIFIED' for c in view['checks'])
        assert {c['case'] for c in view['checks'] if c.get('completed')} == {'second_help','before_night','three_voices'}
        assert any(c.get('evidence_body_comparison')=='VERIFIED' for c in view['checks'])
        for c in view['checks']:
            if 'fixture' in c: assert c['collected'][c['fixture'].split('-')[0]]['complete'] is False
        for shot in view['shots']:
            p = OUT/shot['file']
            assert sha(p) == shot['sha256']
            assert Image.open(p).size == (view['viewport']['width']*view['dpr'],view['viewport']['height']*view['dpr'])
            paths.add(p.relative_to(ROOT).as_posix())
            ui = shot['state']['investigations']['ui']
            texts = [l['text'] for l in ui['labels']+ui['buttons']]
            if any(x in shot['file'] for x in ['before_night-unsorted','before_night-dragging','before_night-sorting','before_night-arranged']):
                assert not re.search(r'(17[：:]42|17[：:]55|18[：:]00)',' '.join(texts)), 'Visible time leak'
            for text in texts:
                assert '\ufffd' not in text and '□' not in text and not re.search(r'\?{3,}',text)
                displayed.update(c for c in text if not c.isspace() and c != '\u2060')
        # The Web bridge samples every 350ms. The first PNG can therefore
        # precede its dragging=true state sample. Verify the rendered ghost
        # in both real PNGs and its displacement; never rewrite stale samples.
        frames = [s for s in view['shots'] if 'before_night-dragging' in s['file']]
        assert len(frames)==2 and any(s['state']['investigations']['ui']['dragging'] for s in frames)
        centroids = []
        for frame in frames:
            ui = frame['state']['investigations']['ui']; dpr = view['dpr']
            drop = ui['drop_zone']
            top = min(b['rect'][1] for b in ui['buttons'] if re.match(r'^[甲乙丙] ',b['text']))
            bounds = tuple(round(v*dpr) for v in [drop[0],top,drop[0]+drop[2],drop[1]+drop[3]])
            pixels = Image.open(OUT/frame['file']).convert('RGB').crop(bounds)
            red = [(x,y) for y in range(pixels.height) for x in range(pixels.width) if (lambda p:p[0]>=150 and p[1]<90 and p[2]<90)(pixels.getpixel((x,y)))]
            assert len(red)>8*dpr, 'Rendered red drag ghost absent'
            centroids.append(sum(y for x,y in red)/len(red))
        assert sha(OUT/frames[0]['file']) != sha(OUT/frames[1]['file']) and abs(centroids[1]-centroids[0])>dpr, 'Ghost did not move between frames'
        motion.append({'viewport':view['tag'],'status':'VERIFIED','red_ghost_y_centroids_px':centroids,'state_interval_ms':350,'method':'Read original PNG pixels inside card/drop area; require visible vermilion ghost in both frames and displacement, plus an actual dragging=true sample.'})
    font = TTFont(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')
    missing = [ord(c) for c in displayed if ord(c) not in font.getBestCmap()]
    font.close()
    assert not missing, {'missing_glyphs':missing}
    small = next(v for v in capture['views'] if v['tag']=='320x568')
    large = next(v for v in capture['views'] if v['tag']=='390x844')
    def summary(view):
        shot = next(s for s in view['shots'] if re.search(r'second_help-action(?:-320x568)?\.png$',s['file']))
        return next(l['text'] for l in shot['state']['investigations']['ui']['labels'] if l['text'].startswith('✓甲'))
    assert summary(small) == summary(large) == '✓甲 服務承諾｜✓乙 同案補充通知'
    selection = [
        ('second_help','phone-second_help-inspect-a.png'),
        ('second_help','phone-second_help-inspect-b.png'),
        ('second_help','phone-second_help-retry.png'),
        ('second_help','phone-second_help-action-retry-320x568.png'),
        ('second_help','phone-second_help-sealed.png'),
        ('before_night','phone-before_night-unsorted.png'),
        ('before_night','phone-before_night-dragging-1.png'),
        ('before_night','phone-before_night-dragging-2.png'),
        ('before_night','phone-before_night-revealed.png'),
        ('before_night','phone-before_night-sealed.png'),
        ('three_voices','phone-three_voices-original-0.png'),
        ('three_voices','phone-three_voices-original-1.png'),
        ('three_voices','phone-three_voices-original-2.png'),
        ('three_voices','phone-three_voices-statement-2.png'),
        ('three_voices','phone-three_voices-sealed.png'),
    ]
    review_dir = OUT/'review-set'; review_dir.mkdir(exist_ok=True)
    review = []
    for i,(case,name) in enumerate(selection,1):
        source_file = OUT/name
        target = review_dir/(f'{i:02d}-'+name.removeprefix('phone-'))
        shutil.copy2(source_file,target)
        w,h = Image.open(target).size
        assert h>w and sha(source_file)==sha(target)
        review.append({'case':case,'source':source_file.relative_to(ROOT).as_posix(),'file':target.relative_to(ROOT).as_posix(),'dimensions':[w,h],'sha256':sha(target)})
        paths.add(target.relative_to(ROOT).as_posix())
    assert len(list(review_dir.glob('*.png')))==15 and Counter(x['case'] for x in review)=={'second_help':5,'before_night':5,'three_voices':5}
    write('docs/content/r4/review-set.json',{'status':'VERIFIED','method':'Byte-identical copies of unedited original phone PNGs; five per case. 07 and 08 are consecutive real touch-drag frames. 11-13 show actual scenes plus original statements; 14 shows the live index and accepted counterexamples; 15 seals all three.','images':review})
    store = []
    for tag in ['1290x2796','2064x2752']:
        view = next(v for v in capture['views'] if v['tag']==tag)
        for name in ['before_night-revealed','three_voices-original-2']:
            shot = next(s for s in view['shots'] if s['file'].endswith(name+'.png') or s['file'].endswith(name+'-'+tag+'.png'))
            target = ROOT/'docs/store/screenshots'/(tag+'-content-r4-'+name+'.png')
            shutil.copy2(OUT/shot['file'],target)
            assert Image.open(target).size == tuple(map(int,tag.split('x')))
            store.append({'file':target.relative_to(ROOT).as_posix(),'sha256':sha(target),'source':'docs/content/r4/'+shot['file']})
            paths.add(target.relative_to(ROOT).as_posix())
    write('docs/store/screenshots/CONTENT_R4_STATUS.json',{'status':'VERIFIED','version':'0.18.0','new_screenshots':store,'existing_screenshots_deleted':False,'method':capture['method']})
    write('docs/content/r4/limitations.json',{'status':'BLOCKED','items':['Muse independent rescore >=8 requires the reviewer; no score invented.','Three randomly selected internal people must explain the time order; real users must explain a document-only comparison.','Native iPhone/iPad/Android testing requires the physical devices.','Performance deferred to the separate task per the current instruction.'],'scope':'Local implementation and automated evidence are verified separately from these unmet acceptance steps.'})
    for directory in ['assets/art/content-r4','godot/assets/art/content-r4']:
        paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/directory).iterdir() if p.is_file())
    paths.update('docs/content/r4/'+n for n in ['ART_PROMPT.txt','manifest.json','export.json','web-build.json','final-tests.json','review-set.json','limitations.json','REVIEW_GALLERY.md','verification.json'])
    paths.add('docs/store/screenshots/CONTENT_R4_STATUS.json')
    assert not set(owner['protected']).intersection(paths)
    result = {'status':'VERIFIED','version':'0.18.0','test_suites':len(tests)-1,'reported_checks':sum(t['reported_checks'] for t in tests),'failures':0,'protected_files_unchanged':len(owner['protected']),'browser_views':len(capture['views']),'review_images':15,'review_case_distribution':dict(Counter(x['case'] for x in review)),'screenshots':sum(len(v['shots']) for v in capture['views']),'store_screenshots':len(store),'generated_art_images':1,'generated_atlas_cells':3,'displayed_glyphs_checked':len(displayed),'pck_sha256':exported['pck_sha256'],'pck_bytes':exported['pck_bytes'],'source_digest':exported['source_fingerprint']['digest'],'external_acceptance':'BLOCKED: Muse rescore, physical devices and human acceptance remain pending.'}
    result['drag_motion'] = motion
    write('docs/content/r4/verification.json',result)
    if stage:
        staged = subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0')
        assert not set(x for x in staged if x)-paths, 'Unrelated index entries'
        names = sorted(paths)
        for i in range(0,len(names),40): subprocess.run(['git','add','--',*names[i:i+40]],cwd=ROOT,check=True)
        findings = []
        required_hits = 0
        all_files = subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0')
        for name in all_files:
            if not name or Path(name).suffix.lower() in {'.blend','.glb','.png','.otf','.wav','.zip','.webp'}: continue
            raw = subprocess.check_output(['git','show',':'+name],cwd=ROOT)
            try: text = raw.decode('utf8')
            except UnicodeError: continue
            findings.extend(scan_text(ROOT/name,text))
            required_hits += len(re.findall(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}',text))
        assert not findings and required_hits==0, {'secret_scan_findings':findings,'required_pattern_hits':required_hits}
        result['secret_scan'] = {'status':'VERIFIED','scope':'Prospective index only; owner drafts and credential directories were not read.','tracked_files':len([x for x in all_files if x]),'findings':[],'required_pattern_hits':0}
        write('docs/content/r4/verification.json',result)
        subprocess.run(['git','add','--','docs/content/r4/verification.json'],cwd=ROOT,check=True)
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage',action='store_true')
    verify(parser.parse_args().stage)
