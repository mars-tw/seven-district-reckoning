"""Verify owned index/source, rendered PNGs and final store-round evidence."""
import argparse
import hashlib
import importlib.util
import json
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/r3-store'

def write(name, value):
    (OUT/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    if not candidate.is_relative_to(ROOT) or candidate == ROOT:
        parser.error('Use an isolated candidate inside this repository')
    spec = importlib.util.spec_from_file_location('test_source', ROOT/'tools/test_game.py')
    test_source = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(test_source)
    fingerprint = test_source.source_fingerprint(candidate/'godot', candidate/'tests', candidate/'web', candidate/'tools')
    mismatches, checked = [], []
    # Unchanged files originate from checkout-index at the recorded baseline;
    # verify every owned staged runtime change, including binary font and UIDs.
    changed = subprocess.check_output(['git','diff','--cached','--name-only','-z'], cwd=ROOT).decode().split('\0')
    for name in changed:
        if not name or name.startswith(('docs/','qa/')): continue
        p = candidate/name
        expected = subprocess.check_output(['git','show',':'+name],cwd=ROOT)
        actual = p.read_bytes() if p.is_file() else b''
        if p.suffix.lower() not in {'.otf','.png','.glb','.wav'}:
            actual,expected = actual.replace(b'\r\n',b'\n'),expected.replace(b'\r\n',b'\n')
        if actual != expected: mismatches.append(name)
        checked.append(name)
    web = json.loads((candidate/'qa/web-build.json').read_text(encoding='utf-8'))
    pck_hash = sha(candidate/'deliverables/web/game.pck')
    provenance = {'status':'VERIFIED' if not mismatches else 'BLOCKED','version':'0.7.0',
                  'baseline_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip(),
                  'candidate_matches_git_index':not mismatches,'files_checked':len(checked),'checked_paths':checked,
                  'mismatches':mismatches,'engine':'4.7.2.stable.official.ed1daf0bf',
                  'web_pck_sha256':pck_hash,'wasm_sha256':web['wasm_original_sha256'],
                  'method':'Git index baseline snapshot; all staged runtime deltas compared after text EOL normalization; original unstaged native work excluded; temporary template overrides restored',
                  'source_fingerprint':fingerprint}
    write('build-provenance.json',provenance)
    write('final-source-fingerprint.json',fingerprint)
    write('web-build-manifest.json',web)
    issues = list(mismatches)
    rendered = []
    for directory in [ROOT/'docs/store/screenshots',OUT/'rendered-small']:
        manifest = json.loads((directory/'manifest.json').read_text(encoding='utf-8'))
        if manifest['status']!='VERIFIED' or manifest['pck_sha256']!=pck_hash:
            issues.append('Capture status/source mismatch: '+directory.name)
        for view in manifest['views']:
            for shot in view['shots']:
                p = directory/shot['file']
                data = p.read_bytes()
                dimensions = struct.unpack('>II',data[16:24])
                wanted = (view['pixels']['width'],view['pixels']['height'])
                if dimensions!=wanted or sha(p)!=shot['sha256']:
                    issues.append('PNG dimension/hash mismatch: '+shot['file'])
                if shot['state'].get('version')!='0.7.0': issues.append('Old capture version')
                if shot['file'].endswith('-sealed.png') and shot['state'].get('case_stage')!=4: issues.append('Unsealed screenshot')
                rendered.append({'path':p.relative_to(ROOT).as_posix(),'pixels':dimensions,'sha256':shot['sha256']})
            if view.get('logs') or view.get('blocked_remote_origins'): issues.append('Browser error or remote request')
    suites = {}
    for version in ['47','472']:
        entries = json.loads((OUT/f'final-source-tests-{version}.json').read_text(encoding='utf-8'))
        suites[version] = {'suites':len(entries)-1,'checks':sum(e['reported_checks'] for e in entries),
                           'failures':sum(e['reported_failures'] for e in entries),
                           'source_fingerprint':entries[0]['source_fingerprint']}
        if any(e['status']!='PASS' for e in entries): issues.append('Failed suite: '+version)
        if entries[0]['source_fingerprint']!=fingerprint: issues.append('Tested source differs: '+version)
    report = {'status':'VERIFIED' if not issues else 'BLOCKED','source_fingerprint':fingerprint,
              'suites':suites,'screenshots':rendered,'issues':issues}
    write('final-verification.json',report)
    print(json.dumps({'status':report['status'],'screenshots':len(rendered),'suites':suites,'issues':issues},ensure_ascii=False))
    return 0 if not issues else 1

if __name__=='__main__': raise SystemExit(main())
