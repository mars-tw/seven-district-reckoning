"""Verify actual R2 artifacts and stage a closed, explicit path set only."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/content/r2'
VERSION = '0.16.0'
BASE_PATHS = '''README.md CREDITS.md docs/OPTIM_PLAN_CONTENT_R2.md docs/CODEX_RESPONSE_CONTENT_R2.md docs/art/PROMPTS.json godot/project.godot godot/assets/fonts/SevenDistrictSansTC-Regular.otf godot/scripts/main.gd godot/scripts/ui/game_hud.gd godot/scripts/ui/investigation_panel.gd godot/scripts/content/content_investigations.gd godot/scripts/content/investigation_field.gd godot/scripts/content/investigation_field.gd.uid godot/data/fraud_cases.json tests/content_r1.gd tests/content_r2.gd tools/test_game.py tools/content_r2_prepare.py tools/content_r2_evidence.mjs tools/content_r2_finalize.py web/shell.html'''.split()
def read(p): return json.loads((ROOT / p).read_text(encoding='utf8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def verify(stage=False):
    owner = read('.audit-tmp/content-r2/ownership.json')
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).decode().strip() == owner['branch']
    assert all((ROOT/p).is_file() and sha(ROOT/p) == h for p,h in owner['protected'].items()), 'Protected file drift'
    tests = read('docs/content/r2/final-tests.json')
    from test_game import SUITES, JS_SUITES
    assert len(tests) == len(SUITES)+len(JS_SUITES)+2 and all(t['status'] == 'PASS' for t in tests), 'Incomplete regression matrix'
    export = read('docs/content/r2/export.json')
    assert export['pck_bytes'] <= 25*1024*1024
    assert all(t['source_fingerprint']['digest'] == export['source_fingerprint']['digest'] for t in tests), 'Test/export source mismatch'
    capture = read('docs/content/r2/manifest.json')
    assert capture['status'] == 'VERIFIED' and len(capture['views']) == 9 and not capture['failures']
    assert capture['pck_sha256'] == export['pck_sha256']
    shots = 0
    for view in capture['views']:
        assert view['status'] == 'VERIFIED' and not view['errors'] and 'NVIDIA' in view['renderer']
        for shot in view['shots']:
            file = OUT/shot['file']
            assert sha(file) == shot['sha256']
            assert Image.open(file).size == (view['viewport']['width']*view['dpr'], view['viewport']['height']*view['dpr'])
            shots += 1
        assert any(c.get('indexeddb_cold_reload') == 'VERIFIED' for c in view['checks'])
        for c in view['checks']:
            if 'fixture' in c: assert c['collected'][c['fixture'].split('-')[0]]['complete'] is False, 'Target completion was supplied by a fixture'
    phone = next(v for v in capture['views'] if v['tag'] == '390x844')
    assert any(c.get('chronological_opens') == 0 and len(c.get('timeline_ten_ui_opens',[])) == 10 for c in phone['checks'])
    art = read('assets/art/content-r2/manifest.json')
    for entry in art['files']:
        assert sha(ROOT/entry['path']) == entry['sha256'] and list(Image.open(ROOT/entry['path']).size) == entry['pixels']
    store = ROOT/'docs/store/screenshots'
    new = []
    for tag in ['1290x2796','2064x2752']:
        for suffix in ['second_help-field-0','second_help-action','before_night-unsorted','three_voices-sealed']:
            source = OUT/('phone-'+suffix+'-'+tag+'.png' if tag == '1290x2796' else tag+'-'+suffix+'.png')
            target = store/(tag+'-content-r2-'+suffix+'.png')
            assert not target.exists() or sha(target) == sha(source), 'Do not overwrite another store artifact'
            target.write_bytes(source.read_bytes())
            new.append({'path':target.relative_to(ROOT).as_posix(),'pixels':list(Image.open(target).size),'sha256':sha(target)})
    store_report = 'docs/store/screenshots/CONTENT_R2_STATUS.json'
    (ROOT/store_report).write_text(json.dumps({'status':'VERIFIED','version':VERSION,'new_screenshots':new,'method':capture['method'],'existing_screenshots_deleted':False},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    swap = read('docs/content/r2/data-swap.json')
    assert swap['status'] == 'VERIFIED' and swap['original_export_source_restored'] and swap['source_digest'] == export['source_fingerprint']['digest']
    assert swap['original_json_sha256'] == sha(ROOT/'godot/data/fraud_cases.json') and swap['variant_pck_sha256'] != export['pck_sha256']
    assert len(swap['shots']) == 2
    for shot in swap['shots']:
        file = OUT/shot['file']
        assert sha(file) == shot['sha256'] and Image.open(file).size == (390,844)
    paths = set(BASE_PATHS+[store_report,'tools/content_r2_data_swap.py','docs/content/r2/data-swap.json']+[r['path'] for r in new])
    paths.update('docs/content/r2/'+s['file'] for s in swap['shots'])
    for directory in ['assets/art/content-r2','godot/assets/art/content-r2']:
        paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/directory).rglob('*') if p.is_file())
    paths.update('docs/content/r2/'+name for name in ['export.json','web-build.json','final-tests.json','manifest.json','verification.json','limitations.json'])
    paths.update('docs/content/r2/'+s['file'] for v in capture['views'] for s in v['shots'])
    assert not paths.intersection(owner['protected'])
    verification = {'status':'VERIFIED','version':VERSION,'test_suites':len(tests)-1,'test_checks':sum(t['reported_checks'] for t in tests),'test_failures':0,'protected_files_unchanged':len(owner['protected']),'source_digest':export['source_fingerprint']['digest'],'pck_sha256':export['pck_sha256'],'pck_bytes':export['pck_bytes'],'browser_views':len(capture['views']),'screenshots':shots,'compiled_data_swap_screenshots':2,'new_store_screenshots':len(new),'art_generated_masters':3,'art_runtime_images':3,'shipping_gate':'BLOCKED','limitations':'Native devices, clean-host performance, human usability and independent Muse >=8 review are not verified.'}
    (OUT/'verification.json').write_text(json.dumps(verification,indent=2)+'\n',encoding='utf8')
    if stage:
        assert all((ROOT/p).is_file() for p in paths), [p for p in paths if not (ROOT/p).is_file()]
        existing = set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0'))-{''}
        assert existing.issubset(paths), 'Unrelated staged paths'
        ordered = sorted(paths)
        for i in range(0,len(ordered),30): subprocess.run(['git','add','--',*ordered[i:i+30]],cwd=ROOT,check=True)
        actual = set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0'))-{''}
        assert actual == paths, (actual-paths,paths-actual)
        scan = subprocess.run(['python','tools/scan_publication.py'],cwd=ROOT,capture_output=True,text=True,encoding='utf8')
        raw = json.loads(scan.stdout)
        classified = []
        for finding in raw['findings']:
            relative = finding['file']
            assert relative == 'godot/assets/art/r8/dusk-sky.webp.import' and finding['type'] == 'api_token', finding
            file = ROOT/relative
            assert file.read_bytes() == subprocess.check_output(['git','show','HEAD:'+relative],cwd=ROOT)
            line = file.read_text(encoding='utf8').splitlines()[finding['line']-1]
            assert re.fullmatch(r'(?:path=|dest_files=\[)"res://\.godot/imported/dusk-sky\.webp-[a-f0-9]{32}\.ctex"\]?',line)
            classified.append(finding)
        required = re.compile(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}')
        hits = []
        for relative in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0'):
            if not relative: continue
            try: text = (ROOT/relative).read_text(encoding='utf8')
            except UnicodeError: continue
            if required.search(text): hits.append(relative)
        assert not hits, hits
        verification['secret_scan'] = {'status':'VERIFIED','actual_secret_count':0,'required_pattern_hits':0,'unchanged_head_cache_false_positives':classified,'raw_scanner_status':raw['status'],'tracked_files':raw['tracked_files'],'scope':'Prospective tracked files only. No credential directories read.'}
        (OUT/'verification.json').write_text(json.dumps(verification,indent=2)+'\n',encoding='utf8')
        subprocess.run(['git','add','--','docs/content/r2/verification.json'],cwd=ROOT,check=True)
        subprocess.run(['git','diff','--cached','--check'],cwd=ROOT,check=True)
    print(json.dumps(verification))

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__);p.add_argument('--stage',action='store_true');a=p.parse_args();verify(a.stage)
