"""Build/verify a committed source handoff; never run or import another game."""
from __future__ import annotations
import argparse
from datetime import date
import hashlib
import io
import json
import re
import stat
import subprocess
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
BASELINE = 'f296dbdbee6696778891b7f471665db2a8bdba24'
PREFIX = 'SevenDistrict-integration-kit/'
META = 'INTEGRATION_KIT.json'
INDEX = 'FILES.sha256.json'
OVERLAYS = ('docs/integration-kit/', 'plan/process-alternate-game-integration-1.md', 'tools/integration_kit.py', 'qa/integration-kit-review.md')
BANNED_PARTS = {'.git', '.godot', '_checks', '.secrets', '.audit-tmp', 'node_modules', '__pycache__', '.wrangler', 'deliverables', 'local'}
REQUIRED = ['AGENTS.md', 'LICENSE', 'LICENSE-ASSETS.md', 'CREDITS.md', 'godot/project.godot', 'docs/integration-kit/README.md', 'docs/integration-kit/OTHER-GPT-PROMPT.md', 'docs/integration-kit/module-contracts.json', 'docs/integration-kit/integration-result.schema.json', 'plan/process-alternate-game-integration-1.md', 'tools/integration_kit.py']


def digest(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


def git(*args: str) -> bytes:
    return subprocess.check_output(['git', *args], cwd=ROOT)


def safe_path(name: str) -> bool:
    path = PurePosixPath(name)
    parts = {p.lower() for p in path.parts}
    filename = path.name.lower()
    return bool(name) and bool(path.name) and '\\' not in name and ':' not in name and not path.is_absolute() and '..' not in path.parts and str(path)==name and not parts.intersection(BANNED_PARTS) and not (filename.startswith('.env') or filename.startswith(('credentials.','secrets.')) or re.fullmatch(r'save\d+\.json(?:\.(?:bak|tmp))?', filename) or filename.endswith(('.pyc', '.blend1', '.zip', '.7z', '.key', '.pem')))


def archive_files(blob: bytes, prefix: str = '') -> dict[str, bytes]:
    files: dict[str, bytes] = {}
    seen: set[str] = set()
    with zipfile.ZipFile(io.BytesIO(blob)) as archive:
        if archive.testzip() is not None: raise ValueError('ZIP CRC mismatch')
        for item in archive.infolist():
            if not item.filename.startswith(prefix): raise ValueError('ZIP entry lacks the required single root')
            name = item.filename[len(prefix):]
            if stat.S_ISLNK(item.external_attr >> 16): raise ValueError('Symlink source entry is not portable')
            if item.is_dir():
                if name and not safe_path(name.rstrip('/')): raise ValueError('Unsafe directory entry')
                continue
            if not safe_path(name): raise ValueError('Unsafe source path: '+name)
            if name.casefold() in seen: raise ValueError('Duplicate or case-colliding source path')
            seen.add(name.casefold())
            files[name] = archive.read(item)
    return files


def commit_archive(ref: str) -> tuple[str, dict[str, bytes]]:
    commit = git('rev-parse', '--verify', ref+'^{commit}').decode().strip()
    if not re.fullmatch('[0-9a-f]{40}', commit): raise ValueError('Expected a resolved commit')
    return commit, archive_files(git('archive', '--format=zip', commit))


def compare_baseline(files: dict[str, bytes], baseline: str) -> dict[str, int]:
    _, original = commit_archive(baseline)
    for name, data in original.items():
        if files.get(name)!=data: raise ValueError('Frozen baseline changed or missing: '+name)
    extras = set(files)-set(original)-{META, INDEX}
    for name in extras:
        if not any(name.startswith(p) if p.endswith('/') else name==p for p in OVERLAYS):
            raise ValueError('Unexpected file outside the handoff overlay: '+name)
    return {'unchanged_baseline_files':len(original), 'handoff_overlay_files':len(extras)}


def inspect(files: dict[str, bytes]) -> dict:
    for path in REQUIRED:
        if path not in files: raise ValueError('Missing required source: '+path)
    project = files['godot/project.godot'].decode('utf-8')
    version_match = re.search(r'^config/version="([^"]+)"',project,re.M)
    if not version_match: raise ValueError('Missing game version')
    contracts = json.loads(files['docs/integration-kit/module-contracts.json'])
    for module in contracts['modules']:
        source = files[module['path']].decode('utf-8')
        for entry in module.get('entrypoints', [])+module.get('internal_integration_points', []):
            name = entry.split('(')[0]
            if not re.search(r'\bfunc\s+'+re.escape(name)+r'\s*\(', source): raise ValueError('Contract function missing: '+name)
    life = json.loads(files['godot/data/taiwan_life.json'])
    activities = json.loads(files['godot/data/taiwan_activities.json'])
    counts = {
        'runtime_glb':sum(p.startswith('godot/assets/models/') and p.endswith('.glb') for p in files),
        'editable_blend':sum(p.startswith('assets/source/blender/') and p.endswith('.blend') for p in files),
        'stations':len(life['stations']), 'story_people':len(life['characters']),
        'story_episodes':len(life['missions']), 'delivery_templates':len(life['delivery_templates']),
        'culture_activities':len(activities['activities']), 'contract_modules':len(contracts['modules']),
        'contract_entrypoints':sum(len(m.get('entrypoints', []))+len(m.get('internal_integration_points', [])) for m in contracts['modules'])
    }
    if counts['runtime_glb']!=61 or counts['stations']!=32 or counts['culture_activities']!=4: raise ValueError('Unexpected Alpha 0.4 baseline inventory')
    return {'game_version':version_match[1], 'counts':counts}


def read_directory(directory: Path) -> dict[str, bytes]:
    index = json.loads((directory/INDEX).read_text(encoding='utf-8'))
    files: dict[str, bytes] = {}
    names = [row['path'] for row in index['files']]+[INDEX]
    if len({name.casefold() for name in names})!=len(names): raise ValueError('Repeated or case-colliding directory index')
    actual_names: set[str] = set()
    for path in directory.rglob('*'):
        if path.is_symlink(): raise ValueError('Symlink found in extracted kit')
        if path.is_file(): actual_names.add(path.relative_to(directory).as_posix())
    if actual_names!=set(names): raise ValueError('Extracted directory has missing or unindexed files; verify a clean extracted kit before importing or initializing Git')
    for name in names:
        if not safe_path(name): raise ValueError('Unsafe indexed path')
        path = directory/name
        resolved = path.resolve()
        if not resolved.is_relative_to(directory.resolve()) or path.is_symlink(): raise ValueError('File escapes source root')
        files[name] = path.read_bytes()
    return files


def verify(files: dict[str, bytes], git_compare: bool = False) -> dict:
    index = json.loads(files[INDEX])
    metadata = json.loads(files[META])
    expected = {row['path']:row for row in index['files']}
    if len(expected)!=len(index['files']): raise ValueError('Repeated index path')
    if set(expected)!=set(files)-{INDEX}: raise ValueError('Archive contents differ from file index')
    for name,row in expected.items():
        if not safe_path(name) or row['bytes']!=len(files[name]) or row['sha256']!=digest(files[name]): raise ValueError('Hash/size mismatch: '+name)
    if index.get('excluded_self')!=INDEX or metadata.get('baseline_commit')!=BASELINE: raise ValueError('Wrong hash convention or baseline')
    observed = inspect(files)
    if observed['counts']!=metadata['counts'] or observed['game_version']!=metadata['game_version']: raise ValueError('Manifest inventory mismatch')
    result = {'status':'PASS','verified_payload_files':len(expected),'zip_index_sha256':digest(files[INDEX]),'baseline_commit':metadata['baseline_commit'],'source_snapshot_commit':metadata['source_snapshot_commit'],**observed,'scope':'Source-package path/hash/contracts verification; no incoming-game compatibility or gameplay execution claim.'}
    if git_compare:
        result.update(compare_baseline(files,metadata['baseline_commit']))
        _, snapshot = commit_archive(metadata['source_snapshot_commit'])
        if {k:v for k,v in files.items() if k not in {META,INDEX}}!=snapshot: raise ValueError('Kit payload differs from its committed source snapshot')
        result['committed_snapshot_bytes_match'] = True
    return result


def build(args) -> None:
    if git('status','--porcelain').strip(): raise ValueError('Commit the handoff source before packaging; no mixed working-tree ZIP')
    ref, files = commit_archive(args.ref)
    baseline, _ = commit_archive(BASELINE)
    comparison = compare_baseline(files,baseline)
    summary = inspect(files)
    metadata = {'schema_version':1,'purpose':'Alternate GPT-created game source intake and bounded integration','game_version':summary['game_version'],'created_on':args.date,'baseline_commit':baseline,'source_snapshot_commit':ref,'production_tag':'v0.4.0','repository':'https://github.com/mars-tw/seven-district-reckoning','engine':'Godot 4.7.2 stable','art_tool':'Blender 5.2.0','counts':summary['counts'],'baseline_bytes_preserved':comparison,'read_first':['AGENTS.md','docs/integration-kit/OTHER-GPT-PROMPT.md','docs/integration-kit/module-contracts.json','plan/process-alternate-game-integration-1.md'],'license_authority':['LICENSE','LICENSE-ASSETS.md','CREDITS.md','assets/provenance/'],'incoming_game_status':'not_received_not_merged','entry_project':'godot/project.godot','file_index':INDEX,'file_index_rule':'SHA-256 of all payload files, including this metadata; FILES.sha256.json excludes itself and has its own external ZIP digest.'}
    files[META] = (json.dumps(metadata,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
    index = {'schema_version':1,'algorithm':'sha256','excluded_self':INDEX,'files':[{'path':name,'bytes':len(blob),'sha256':digest(blob)} for name,blob in sorted(files.items())]}
    files[INDEX] = (json.dumps(index,indent=2)+'\n').encode('utf-8')
    output = ROOT/'deliverables'/f"SevenDistrict-{summary['game_version']}-integration-kit-{args.date.replace('-','')}.zip"
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name,blob in sorted(files.items()):
            published_date = date.fromisoformat(args.date)
            item = zipfile.ZipInfo(PREFIX+name,(published_date.year,published_date.month,published_date.day,0,0,0))
            item.compress_type = zipfile.ZIP_DEFLATED
            item.external_attr = 0o100644 << 16
            archive.writestr(item,blob)
    actual = archive_files(output.read_bytes(),PREFIX)
    result = verify(actual,True)
    checksum = digest(output.read_bytes())
    output.with_suffix('.zip.sha256').write_text(checksum+'  '+output.name+'\n',encoding='utf-8')
    result.update({'archive':output.relative_to(ROOT).as_posix(),'archive_bytes':output.stat().st_size,'archive_sha256':checksum})
    report = ROOT/'qa/local/integration-kit-build.json'
    report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command',required=True)
    builder = sub.add_parser('build')
    builder.add_argument('--ref',default='HEAD')
    builder.add_argument('--date',default='2026-10-05')
    verifier = sub.add_parser('verify')
    source = verifier.add_mutually_exclusive_group(required=True)
    source.add_argument('--archive',type=Path)
    source.add_argument('--directory',type=Path)
    verifier.add_argument('--git-compare',action='store_true')
    args = parser.parse_args()
    if args.command=='build':
        if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',args.date): raise ValueError('Use YYYY-MM-DD')
        build(args)
    else:
        files = archive_files(args.archive.read_bytes(),PREFIX) if args.archive else read_directory(args.directory)
        print(json.dumps(verify(files,args.git_compare)))


if __name__=='__main__': main()
