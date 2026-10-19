"""Verify asset provenance, original-size capture evidence and index isolation."""
import hashlib
import json
import re
import subprocess
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/r6-art'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assets = json.loads((ROOT/'godot/assets/art/r6/manifest.json').read_text())
    for record in assets['outputs']:
        p = ROOT/record['path']
        assert sha(p) == record['sha256'] and list(Image.open(p).size) == record['size']
        assert sha(ROOT/record['master']) == record['master_sha256']
        assert Path(str(p)+'.import').is_file()
        if 'reference' in record: assert sha(ROOT/record['reference']) == record['reference_sha256']
        if 'alpha' in record:
            assert record['alpha']['corners'] == [0]*4 and record['character_gate']['pass']
            assert sha(ROOT/record['alpha']['mask']) == record['alpha']['mask_sha256']
            assert all(px[:3] == (0,0,0) for px in Image.open(p).getdata() if px[3] == 0)
    captures = json.loads((ROOT/'docs/art/compare/r6-after/manifest.json').read_text(encoding='utf8'))
    assert captures['status'] == 'VERIFIED' and not captures['failures']
    assert len(captures['views']) == 7
    stores = []
    for view in captures['views']:
        assert 'NVIDIA' in view['game_renderer'] and view['last_layout']['peak_sorts_per_frame'] <= 32
        assert len(view['shots']) == 7 and len(view['inspections']) == 2 and len(view['reopen_checks']) == 3
        size = (view['pixels']['width'], view['pixels']['height'])
        records = view['shots']+view['inspections']+view.get('street_angles',[])+view.get('seal_screencast',[])+view.get('seal_animation',[])
        for record in records:
            p = ROOT/'docs/art/compare/r6-after'/record['file']
            assert sha(p) == record['sha256'] and Image.open(p).size == size, record['file']
        for record in view['shots']:
            assert record['state']['version'] == '0.10.0'
            if size[0] in [1290,2064]:
                p = ROOT/'docs/store/screenshots'/record['file']
                assert p.is_file() and sha(p) == record['sha256']
                stores.append(record['file'])
        if size == (390,844):
            street = next(s['state'] for s in view['shots'] if s['file'].endswith('-street.png'))
            assert street['art']['hero_height_px'] >= 40 and street['art']['mei_height_px'] >= 40
            assert len(street['art']['details']['touch']) == 2
            sequence = view['seal_animation']
            assert len(sequence) == 3 and len({s['sha256'] for s in sequence}) == 3
            assert sequence[0]['timestamp'] < sequence[1]['timestamp'] < sequence[2]['timestamp']
    assert len(stores) == 14
    protected = json.loads((OUT/'protected-before.json').read_text())
    mismatches = [p for p,h in protected.items() if not (ROOT/p).is_file() or sha(ROOT/p) != h]
    assert not mismatches, mismatches
    missing = [p for p in json.loads((OUT/'initial-untracked.json').read_text()) if not (ROOT/p).exists()]
    assert not missing, missing
    tests = json.loads((OUT/'final-source-tests.json').read_text(encoding='utf8'))
    assert len(tests) == 27 and all(r['status'] == 'PASS' and not r['reported_failures'] for r in tests)
    patterns = [re.compile(r'(?:sk-(?:proj-|sp-|ws-)?[A-Za-z0-9_.-]{28,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'),
                re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
                re.compile(r'[A-Za-z]:[/\\]Users[/\\][^/\\\s"\x27]+[/\\]',re.I),
                re.compile(r'(?:1//[A-Za-z0-9_-]{35,}|AQX[A-Za-z0-9_-]{100,})')]
    findings = []
    scanned = 0
    for entry in subprocess.check_output(['git','ls-files','--stage','-z'],cwd=ROOT).decode().split('\0'):
        if not entry: continue
        _, obj, rest = entry.split(' ',2)
        _, name = rest.split('\t',1)
        if Path(name).suffix.lower() not in ['.gd','.gdshader','.py','.mjs','.js','.json','.md','.html','.cfg','.yml','.txt','.godot','.import','.uid','.css']: continue
        data = subprocess.check_output(['git','cat-file','blob',obj],cwd=ROOT).decode('utf8',errors='replace')
        scanned += 1
        if any(p.search(data) for p in patterns): findings.append(name)
    assert not findings, findings
    report = dict(status='VERIFIED', version='0.10.0', assets=4, store_screenshots=stores,
                  protected_files=len(protected), protected_mismatches=mismatches, missing_initial_untracked=missing,
                  test_suites=len(tests)-1, reported_checks=sum(t['reported_checks'] for t in tests),
                  scanned_index_text_files=scanned, secret_findings=findings,
                  captures_sha256=sha(ROOT/'docs/art/compare/r6-after/manifest.json'), pck_sha256=captures['pck_sha256'])
    (OUT/'artifact-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['status','test_suites','reported_checks','protected_files','secret_findings']}))

if __name__ == '__main__':
    main()
