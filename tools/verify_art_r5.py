"""Read back R5 assets, captures, preservation and prospective index secrets."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/r5-art'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    manifest = json.loads((ROOT / 'godot/assets/art/r5/manifest.json').read_text())
    checked = []
    for r in manifest['outputs']:
        path = ROOT / r['path']
        im = Image.open(path)
        assert list(im.size) == r['size'] and sha(path) == r['sha256'], r['id']
        assert sha(ROOT / r['master']) == r['master_sha256']
        assert Path(str(path) + '.import').is_file()
        if r.get('alpha'):
            assert im.mode == 'RGBA' and r['alpha']['corners'] == [0, 0, 0, 0]
            assert all(px[:3] == (0, 0, 0) for px in im.getdata() if px[3] == 0)
        checked.append(r['id'])
    captures = json.loads((ROOT / 'docs/art/compare/r5-after/manifest.json').read_text(encoding='utf-8'))
    assert captures['status'] == 'VERIFIED' and not captures['failures']
    budget = json.loads((OUT / 'package-budget.json').read_text())
    assert captures['pck_sha256'] == budget['candidate_pck_sha256']
    for mask in json.loads((ROOT / 'assets/art/r5/alpha-masks.json').read_text())['masks']:
        assert sha(ROOT / mask['path']) == mask['sha256']
    stores = []
    for view in captures['views']:
        assert 'NVIDIA' in view['game_renderer'] and view['last_layout']['peak_sorts_per_frame'] <= 32
        assert len(view['shots']) == 7 and len(view['reopen_checks']) == 3
        for shot in view['shots']:
            path = ROOT / 'docs/art/compare/r5-after' / shot['file']
            im = Image.open(path)
            assert sha(path) == shot['sha256']
            assert list(im.size) == list(view['pixels'].values())
            assert shot['state']['version'] == '0.9.0'
            if im.width in [1290, 2064]:
                store = ROOT / 'docs/store/screenshots' / shot['file']
                assert store.is_file() and sha(store) == sha(path)
                stores.append(shot['file'])
        if view['viewport'] == {'width': 390, 'height': 844}:
            state = next(s['state'] for s in view['shots'] if s['file'].endswith('-street.png'))
            assert state['art']['hero_height_px'] >= 40 and state['art']['mei_height_px'] >= 40
    assert len(stores) == 14
    protected = json.loads((OUT / 'protected-before.json').read_text())
    mismatch = [p for p, h in protected.items() if not (ROOT / p).is_file() or sha(ROOT / p) != h]
    assert not mismatch, mismatch
    entries = subprocess.check_output(['git', 'ls-files', '--stage', '-z'], cwd=ROOT).decode().split('\0')
    patterns = [re.compile(r'(?:sk-(?:proj-|sp-|ws-)?[A-Za-z0-9_.-]{28,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'),
                re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
                re.compile(r'[A-Za-z]:[/\\]Users[/\\][^/\\\s"\x27]+[/\\]', re.I)]
    findings = []
    scanned = 0
    for entry in entries:
        if not entry:
            continue
        _, obj, rest = entry.split(' ', 2)
        _, name = rest.split('\t', 1)
        if Path(name).suffix.lower() not in ['.gd', '.gdshader', '.py', '.mjs', '.js', '.json', '.md', '.html', '.cfg', '.yml', '.txt', '.godot', '.import', '.uid', '.css']:
            continue
        data = subprocess.check_output(['git', 'cat-file', 'blob', obj]).decode('utf-8', errors='replace')
        scanned += 1
        if any(p.search(data) for p in patterns):
            findings.append(name)
    assert not findings, findings
    report = dict(status='VERIFIED', version='0.9.0', assets=checked, store_screenshots=stores,
                  protected_files=len(protected), protected_mismatches=mismatch,
                  scanned_index_text_files=scanned, secret_findings=findings,
                  captures_sha256=sha(ROOT / 'docs/art/compare/r5-after/manifest.json'))
    (OUT / 'artifact-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['status', 'protected_files', 'secret_findings']}))


if __name__ == '__main__':
    main()
