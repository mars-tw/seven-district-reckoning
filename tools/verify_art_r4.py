"""Verify R4 file evidence without using a renderer, browser or external service."""
import hashlib
import importlib.util
import json
import re
import subprocess
from pathlib import Path

from PIL import Image
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/evidence/r4-art'


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(name, data): (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')


def main():
    spec=importlib.util.spec_from_file_location('art_pipeline',ROOT/'tools/prepare_art_r4.py')
    pipeline=importlib.util.module_from_spec(spec); spec.loader.exec_module(pipeline)
    manifest=json.loads((ROOT/'assets/art/r4/manifest.json').read_text(encoding='utf8'))
    issues=[]
    for entry in manifest['assets'] + manifest['outputs'] + manifest['alpha_masks']:
        path=ROOT/entry.get('path',entry.get('master',''))
        if not path.is_file() or sha(path)!=entry['sha256']: issues.append('hash:'+str(path.relative_to(ROOT)))
    for entry in manifest['outputs']:
        image=Image.open(ROOT/entry['path'])
        if image.mode=='RGBA':
            alpha=image.getchannel('A')
            corners=[alpha.getpixel((x,y)) for x,y in [(0,0),(image.width-1,0),(0,image.height-1),(image.width-1,image.height-1)]]
            if max(corners)!=0: issues.append('alpha_corners:'+entry['id'])
        if 'character_gate' in entry and not pipeline.metrics(image)['pass']: issues.append('portrait_gate:'+entry['id'])
    write('asset-verification.json',{'status':'VERIFIED' if not issues else 'BLOCKED','issues':issues,
          'generated_masters':len(manifest['assets']),'runtime_images':len(manifest['outputs']),
          'runtime_bytes':manifest['runtime_bytes'],'estimated_decoded_rgba_bytes':manifest['estimated_runtime_rgba_bytes'],
          'source_master_bytes':manifest['master_bytes'],'source_masters_excluded_from_runtime':True,
          'pixel_runtime_review':'BLOCKED','character_thumbnail_review':'Two portraits visually inspected at 64px; no human blind test or 3D three-view validation'})
    cmap=TTFont(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf').getBestCmap()
    strings=''.join(p.read_text(encoding='utf8') for p in (ROOT/'godot/scripts').rglob('*.gd'))
    missing=sorted(set(c for c in strings if '\u3400'<=c<='\u9fff' and ord(c) not in cmap))
    write('font-verification.json',{'status':'VERIFIED' if not missing else 'BLOCKED','missing_cjk':missing,'font_sha256':sha(ROOT/'godot/assets/fonts/SevenDistrictSansTC-Regular.otf')})
    issues.extend('missing_cjk:'+c for c in missing)
    baseline=json.loads((OUT/'preexisting-worktree.json').read_text(encoding='utf8'))
    preservation=[]
    for label,oldhash in baseline.items():
        path=ROOT/label; same=path.is_file() and sha(path)==oldhash
        allowed=label in ['tests/native_touch.gd','godot/export_presets.cfg']
        preserved=same
        if label=='godot/export_presets.cfg':
            original=path.read_bytes().replace(b'0.8.0.0',b'0.7.0.0')
            preserved=hashlib.sha256(original).hexdigest()==oldhash
        if label=='tests/native_touch.gd': preserved=path.is_file() and 'Native world reaches its startup readiness contract' in path.read_text(encoding='utf8')
        preservation.append({'path':label,'unchanged':same,'expected_scoped_edit':allowed,'preserved':preserved})
        if not preserved: issues.append('preexisting:'+label)
    write('preexisting-integrity.json',{'status':'VERIFIED' if all(x['preserved'] for x in preservation) else 'BLOCKED','files':preservation,'deleted':[]})
    live={label:(ROOT/label).read_text(encoding='utf8') for label in ['godot/project.godot','godot/export_presets.cfg','web/shell.html','README.md']}
    old=[label for label,s in live.items() if '0.7.0' in s]
    write('version-audit.json',{'status':'VERIFIED' if not old else 'BLOCKED','version':'0.8.0','live_config_old_version_hits':old,'historical_evidence_and_R3_replay_tools':'retain their historical versions'})
    issues.extend('old_version:'+p for p in old)
    # git ls-files is the prospective publication scope; never inspect secret directories.
    names=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0')
    patterns=[('required_api_token',re.compile(r'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}')),
              ('private_key',re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
              ('github_token',re.compile(r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'))]
    findings=[]
    for name in filter(None,names):
        try: content=(ROOT/name).read_text(encoding='utf8')
        except (UnicodeError,IsADirectoryError): continue
        for kind,pattern in patterns:
            if pattern.search(content): findings.append({'file':name,'type':kind})
    write('secret-scan.json',{'status':'VERIFIED' if not findings else 'BLOCKED','scope':'prospective tracked file contents; no credentials directories accessed','findings':findings,'file_count':len(names)-1})
    issues.extend('secret:'+x['file'] for x in findings)
    write('file-verification.json',{'status':'VERIFIED' if not issues else 'BLOCKED','issues':issues,
          'runtime_capture':'BLOCKED','store_recapture':'BLOCKED','p95_shipping_gate':'BLOCKED','native_test':'See final-tests.json; screenshot blocker does not imply native input blocker'})
    print(json.dumps({'status':'VERIFIED' if not issues else 'BLOCKED','issues':issues,'runtime_bytes':manifest['runtime_bytes']}))
    return 1 if issues else 0


if __name__=='__main__': raise SystemExit(main())
