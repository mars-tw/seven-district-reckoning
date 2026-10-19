"""Read-only sibling hash comparison; writes evidence only into this repository."""
import argparse
import hashlib
import json
import os
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/r3-store'
SIBLINGS = ['rift-survivors', 'storm-apocalypse', 'doomsday-shooter', 'tower-defense',
            'skill', 'pixel-idle-farm-skill', 'village-siege', 'rift-forge-3d',
            'taiwan-island-drive', 'taiwan-train-math', 'island-flight-school',
            'taiwan-train-school', '夜行列車_重製企劃_20261002']
SKIP = {'.git', '.godot', 'node_modules', 'Library', 'Temp', 'Logs', 'obj', 'bin',
        'deliverables', 'release', 'dist', 'build', 'output', 'downloads', 'archives',
        '.audit-tmp', '.tools', '.venv', '__pycache__', 'android', 'docs', 'qa', 'reports',
        'evidence', 'screenshots', '.secrets'}
SUFFIXES = {'.gd', '.cs', '.js', '.ts', '.tsx', '.jsx', '.mjs', '.css', '.html', '.json',
            '.svg', '.png', '.jpg', '.webp', '.wav', '.ogg', '.mp3', '.otf', '.ttf',
            '.woff', '.woff2', '.glb', '.gltf', '.tscn', '.gdshader'}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def files(directory):
    for base, dirs, names in os.walk(directory):
        dirs[:] = sorted(d for d in dirs if d not in SKIP and not d.startswith('.'))
        for name in sorted(names):
            p = Path(base) / name
            if p.suffix.lower() in SUFFIXES:
                yield p

def write(name, data):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def shared():
    own = list(files(ROOT/'godot')) + list(files(ROOT/'web'))
    by_size = defaultdict(list)
    inventory = []
    for p in own:
        row = {'path':p.relative_to(ROOT).as_posix(), 'bytes':p.stat().st_size, 'sha256':digest(p)}
        by_size[row['bytes']].append(row)
        inventory.append(row)
    matches, scanned, unavailable = [], {}, []
    for name in SIBLINGS:
        directory = ROOT.parent / name
        if not directory.is_dir():
            unavailable.append(name)
            continue
        count = candidates = 0
        for p in files(directory):
            count += 1
            size = p.stat().st_size
            if size not in by_size: continue
            candidates += 1
            checksum = digest(p)
            for row in by_size[size]:
                if row['sha256'] == checksum:
                    matches.append({'file':row['path'], 'other_game':name,
                                    'other_file':p.relative_to(directory).as_posix(), 'sha256':checksum})
        scanned[name] = {'files_considered':count,'size_matched_files_hashed':candidates}
    write('shared-assets.json', {'status':'VERIFIED','method':'SHA-256 on runtime source/assets; exact byte duplicates only; standard frameworks and semantic similarity require manual review',
          'scope':'Owned godot/ and web/ versus explicit sibling roots, excluding generated/cache/private/report/vendor directories',
          'own_files':len(inventory), 'siblings':scanned, 'unavailable':unavailable, 'matches':matches})
    write('runtime-asset-inventory.json', inventory)
    print(f'Shared asset audit: {len(inventory)} owned files, {len(scanned)} siblings, {len(matches)} exact matches')

def verify_original():
    before = json.loads((OUT/'preexisting-worktree.json').read_text(encoding='utf-8'))
    result = []
    for row in before:
        p = ROOT / row['path']
        result.append({'path':row['path'], 'unchanged':p.is_file() and digest(p)==row['sha256'],
                       'before_sha256':row['sha256'], 'after_sha256':digest(p) if p.is_file() else None})
    write('preexisting-integrity.json',result)
    print('Preexisting files unchanged:',sum(r['unchanged'] for r in result),'/',len(result))
    # export_presets contains one deliberate own-version delta, audited separately.
    return all(r['unchanged'] or r['path']=='godot/export_presets.cfg' for r in result)

def secrets():
    # Report paths and line numbers only, never matching text or credentials.
    rules = [r'sk-proj-[A-Za-z0-9_-]{20,}', r'sk-[a-z0-9]{40}',
             r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
             r'AKIA[0-9A-Z]{16}', r'gh[pousr]_[A-Za-z0-9]{36,}']
    hits, checked = [], 0
    for base, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP and d not in {'.codex','.claude'}]
        for name in names:
            p = Path(base)/name
            if p.stat().st_size > 8*1024*1024: continue
            try: data = p.read_text(encoding='utf-8')
            except (UnicodeError,OSError): continue
            checked += 1
            for i,line in enumerate(data.splitlines(),1):
                if any(re.search(pattern,line) for pattern in rules): hits.append({'path':p.relative_to(ROOT).as_posix(),'line':i})
    write('secret-scan.json',{'status':'VERIFIED' if not hits else 'BLOCKED','files_scanned':checked,'hits':hits,
                            'excludes':'git, caches, vendor, source archives, generated outputs, historical docs/qa; staged files scanned separately'})
    print('Secret hits:',len(hits))
    return not hits

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['shared','verify-original','secrets'])
    action = parser.parse_args().action
    if action=='shared': shared()
    elif action=='verify-original': raise SystemExit(0 if verify_original() else 1)
    else: raise SystemExit(0 if secrets() else 1)
