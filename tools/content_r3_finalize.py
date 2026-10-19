"""Verify the closed R3 artifact set, then stage only explicit owned paths."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from PIL import Image
from fontTools.ttLib import TTFont
from scan_publication import root as scan_root, scan_text
from test_game import SUITES, JS_SUITES

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/content/r3'
BASE = '''README.md godot/project.godot web/shell.html godot/assets/fonts/SevenDistrictSansTC-Regular.otf godot/data/fraud_cases.json godot/scripts/main.gd godot/scripts/ui/game_hud.gd godot/scripts/ui/investigation_panel.gd godot/scripts/content/content_investigations.gd godot/scripts/content/investigation_field.gd godot/scripts/content/taiwan_world.gd tests/content_r1.gd tests/content_r2.gd tests/content_r3.gd tools/test_game.py tools/scan_publication.py tools/content_r3_prepare.py tools/content_r3_evidence.mjs tools/content_r3_capture.py tools/content_r3_data_swap.py tools/content_r3_finalize.py docs/OPTIM_PLAN_CONTENT_R3.md docs/CODEX_RESPONSE_CONTENT_R3.md'''.split()

def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def scanner_regression():
    # Synthetic strings are constructed locally, never credentials.
    token = 'sk'+'-'+'q'*40
    imported = scan_root/'godot/assets/art/r8/dusk-sky.webp.import'
    reference = '"res://.godot/imported/dusk-sky.webp-'+'a'*32+'.ctex"'
    for line in ['path='+reference, 'dest_files=['+reference+']']:
        assert not scan_text(imported,line)
        assert scan_text(imported,line+' '+token), 'Trailing credential must still be detected'
    for name, text in [('sample.txt',token),('sample.import',token),('sample.import','value="'+token+'"')]:
        assert scan_text(scan_root/name,text), 'Credential detection weakened'
    assert scan_text(scan_root/'sample.txt','path='+reference), 'Exception must require an import file'
    assert scan_text(imported,'path='+reference.replace('dusk-sky.webp','dusk-sky2.webp')), 'Exception must match source filename'
    assert scan_text(imported,'path='+reference.replace('a'*32,'a'*31)), 'Exception must require full cache hash'
    return 10

def verify(stage=False):
    owner = read('.audit-tmp/content-r3/ownership.json')
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).decode().strip() == owner['branch']
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip() == owner['head'], 'Base commit changed during verification'
    assert all((ROOT/p).is_file() and sha(ROOT/p) == h for p,h in owner['protected'].items()), 'Protected owner file drift'
    tests = read('docs/content/r3/final-tests.json')
    assert len(tests) == len(SUITES)+len(JS_SUITES)+2 and all(t['status']=='PASS' for t in tests)
    exported = read('docs/content/r3/export.json')
    assert exported['pck_bytes'] <= 25*1024*1024
    assert exported['font_subset_sha256'] == sha(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')
    assert all(t['source_fingerprint']['digest'] == exported['source_fingerprint']['digest'] for t in tests)
    capture = read('docs/content/r3/manifest.json')
    assert capture['status']=='VERIFIED' and len(capture['views'])==9 and not capture['failures']
    assert capture['pck_sha256']==exported['pck_sha256']
    paths = set(BASE)
    font = TTFont(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')
    cmap = font.getBestCmap()
    displayed = set()
    for view in capture['views']:
        assert view['status']=='VERIFIED' and not view['errors'] and 'NVIDIA' in view['renderer']
        assert any(c.get('indexeddb_cold_reload')=='VERIFIED' for c in view['checks'])
        for item in view['checks']:
            if 'fixture' in item: assert item['collected'][item['fixture'].split('-')[0]]['complete'] is False
        for shot in view['shots']:
            file=OUT/shot['file']
            assert sha(file)==shot['sha256']
            assert Image.open(file).size==(view['viewport']['width']*view['dpr'],view['viewport']['height']*view['dpr'])
            paths.add(file.relative_to(ROOT).as_posix())
            field = shot['state']['investigations']['field']
            ui = shot['state']['investigations']['ui']
            for text in [field['objective']] + [item['text'] for item in ui['labels']+ui['buttons']]:
                assert '□' not in text and not re.search(r'\?{3,}',text)
                displayed.update(c for c in text if not c.isspace())
    missing = sorted(ord(c) for c in displayed if ord(c) not in cmap)
    font.close()
    assert not missing, {'missing_glyphs':missing}
    phone=next(v for v in capture['views'] if v['tag']=='390x844')
    assert any(c.get('continuous_touch_walk',{}).get('distance_m',0)>1 for c in phone['checks'])
    assert any(len(c.get('timeline_ten_ui_opens',[]))==10 and c['chronological_opens']==0 for c in phone['checks'])
    names={s['file'] for s in phone['shots']}
    required=['three_voices-statement-0','three_voices-statement-1','three_voices-statement-2','three_voices-index-accepted-0','three_voices-index-accepted-1','three_voices-sealed','before_night-unsorted','before_night-sorting','before_night-wrong','before_night-arranged','before_night-revealed','before_night-sealed','second_help-compare','second_help-action-retry','second_help-sealed']
    assert all('phone-'+n+'.png' in names for n in required)
    small=next(v for v in capture['views'] if v['tag']=='320x568')
    arranged=next(s for s in small['shots'] if '-arranged-' in s['file'])
    assert all(any(word in label['text'] for label in arranged['state']['investigations']['ui']['labels']) for word in ['車店收據・先留存','交接摘要・再交接','側門晚班單・後開班'])
    swap=read('docs/content/r3/data-swap.json')
    assert swap['status']=='VERIFIED' and swap['original_export_source_restored'] and swap['source_digest']==exported['source_fingerprint']['digest']
    assert swap['original_json_sha256']==sha(ROOT/'godot/data/fraud_cases.json') and swap['variant_pck_sha256']!=exported['pck_sha256']
    for shot in swap['shots']:
        assert sha(OUT/shot['file'])==shot['sha256'] and Image.open(OUT/shot['file']).size==(390,844)
        paths.add('docs/content/r3/'+shot['file'])
    store=[]
    for tag in ['1290x2796','2064x2752']:
        for name in ['three_voices-field-0','before_night-revealed','three_voices-sealed']:
            source=OUT/(('phone-'+name+'-'+tag) if tag=='1290x2796' else tag+'-'+name)
            source=source.with_suffix('.png')
            target=ROOT/'docs/store/screenshots'/f'{tag}-content-r3-{name}.png'
            assert not target.exists() or sha(target)==sha(source), 'Store artifact collision'
            target.write_bytes(source.read_bytes())
            store.append({'path':target.relative_to(ROOT).as_posix(),'pixels':list(Image.open(target).size),'sha256':sha(target)})
    store_report='docs/store/screenshots/CONTENT_R3_STATUS.json'
    (ROOT/store_report).write_text(json.dumps({'status':'VERIFIED','version':'0.17.0','new_screenshots':store,'method':capture['method'],'existing_screenshots_deleted':False},indent=2)+'\n',encoding='utf8')
    paths.update(s['path'] for s in store)
    paths.add(store_report)
    paths.update('docs/content/r3/'+n for n in ['export.json','web-build.json','final-tests.json','manifest.json','data-swap.json','host-load.json','verification.json','REVIEW_GALLERY.md','limitations.json'])
    assert not paths.intersection(owner['protected'])
    packet=read('godot/data/fraud_cases.json')
    assert len({len(s) for s in packet['cases'][0]['action_choices']})==1
    response=(ROOT/'docs/CODEX_RESPONSE_CONTENT_R3.md').read_text(encoding='utf8')
    assert '後補入' not in response and '28,610' in response
    assert not any(re.search(r'\?{3,}',(ROOT/p).read_text(encoding='utf8')) for p in BASE if Path(p).suffix in ['.gd','.json','.mjs'])
    scanner_checks=scanner_regression()
    verified={'status':'VERIFIED','version':'0.17.0','test_suites':len(tests)-1,'reported_checks':sum(t['reported_checks'] for t in tests),'failures':0,'scanner_regressions':scanner_checks,'protected_files_unchanged':len(owner['protected']),'browser_views':len(capture['views']),'screenshots':sum(len(v['shots']) for v in capture['views'])+len(swap['shots']),'store_screenshots':len(store),'generated_art':0,'source_digest':exported['source_fingerprint']['digest'],'pck_sha256':exported['pck_sha256'],'pck_bytes':exported['pck_bytes'],'shipping_gate':'BLOCKED','limitations':'Independent Muse rescore, native devices, human trials and clean-host p95 remain unverified.'}
    verified['displayed_glyphs_checked'] = len(displayed)
    verified['font_subset_sha256'] = exported['font_subset_sha256']
    pacing=[{'viewport':v['tag'],'runs':v['frame_pacing']['runs'],'p95_median_ms':v['frame_pacing']['p95_median']} for v in capture['views'] if v.get('frame_pacing')]
    verified['reference_performance']={'status':'VERIFIED','scope':'Concurrent browser RAF reference only, not a clean-host or native-device result','threshold_ms':18,'all_measured_views_under_threshold':all(p['p95_median_ms']<=18 for p in pacing),'views':pacing}
    (OUT/'verification.json').write_text(json.dumps(verified,indent=2)+'\n',encoding='utf8')
    if stage:
        existing=set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0'))-{''}
        assert existing.issubset(paths),'Unrelated staged paths'
        ordered=sorted(paths)
        for i in range(0,len(ordered),30): subprocess.run(['git','add','--',*ordered[i:i+30]],cwd=ROOT,check=True)
        actual=set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0'))-{''}
        assert actual==paths,(actual-paths,paths-actual)
        scan=subprocess.run(['python','tools/scan_publication.py'],cwd=ROOT,capture_output=True,text=True,encoding='utf8')
        raw=json.loads(scan.stdout)
        assert scan.returncode==0 and raw['status']=='PASS' and not raw['findings'],raw
        hits=[]
        pattern=re.compile(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}')
        for name in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0'):
            if not name: continue
            try: text=(ROOT/name).read_text(encoding='utf8')
            except UnicodeError: continue
            if pattern.search(text): hits.append(name)
        assert not hits,hits
        verified['secret_scan']={'status':'VERIFIED','findings':[],'required_pattern_hits':0,'tracked_files':raw['tracked_files'],'scope':'Prospective tracked files only. No credential directory access.'}
        (OUT/'verification.json').write_text(json.dumps(verified,indent=2)+'\n',encoding='utf8')
        subprocess.run(['git','add','--','docs/content/r3/verification.json'],cwd=ROOT,check=True)
        subprocess.run(['git','diff','--cached','--check'],cwd=ROOT,check=True)
    print(json.dumps(verified))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--stage',action='store_true');args=parser.parse_args();verify(args.stage)
